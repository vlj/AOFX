//
// Copyright (c) 2016 Advanced Micro Devices, Inc. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#if ( AOFX_IMPLEMENTATION == AOFX_IMPLEMENTATION_CS )

struct CompressedPosition
{
# if AO_STORE_XY_LDS
  uint                                           position_xy;
# endif // AO_STORE_XY_LDS
  float                                          position_z;
};

shared CompressedPosition                   g_SharedCache[AO_GROUP_TEXEL_DIM][AO_GROUP_TEXEL_DIM];

// Helper function to load data from the LDS, given texel coord
// NOTE: X and Y are swapped around to ensure horizonatal reading across threads, this avoids
// LDS memory bank conflicts
vec3 fetchPositionFromCache(vec2 screenCoord, uvec2 cacheCoord, ivec2 layerIdx)
{
  float position_z = g_SharedCache[cacheCoord.y][cacheCoord.x].position_z;

# if AO_STORE_XY_LDS
  vec2 position = uintToFloat2(g_SharedCache[cacheCoord.y][cacheCoord.x].position_xy);
# else
  // Convert screen coords to projection space XY
  position = screenCoord * g_cbAO.m_InputSizeRcp - vec2(1.0f, 1.0f);
  position.x = position.x * g_cbAO.m_CameraTanHalfFovHorizontal * position_z;
  position.y = -position.y * g_cbAO.m_CameraTanHalfFovVertical   * position_z;
# endif // AO_STORE_XY_LDS

  return vec3(position.x, position.y, position_z);
}

// Helper function to store data to the LDS, given texel coord
// NOTE: X and Y are swapped around to ensure horizonatal wrting across threads, this avoids
// LDS memory bank conflicts
void storePositionInCache(vec3 position, uvec2 cacheCoord)
{
# if AO_STORE_XY_LDS
  g_SharedCache[cacheCoord.y][cacheCoord.x].position_xy = float2ToUint32(position.xy);
# endif // AO_STORE_XY_LDS

  g_SharedCache[cacheCoord.y][cacheCoord.x].position_z = position.z;
}

#elif ( AOFX_IMPLEMENTATION == AOFX_IMPLEMENTATION_PS )

vec3 fetchPositionFromCache(vec2 screenCoord, uvec2 cacheCoord, ivec2 layerIdx)
{
  return loadCameraSpacePositionT2D(screenCoord, layerIdx);
}

#endif // ( AOFX_IMPLEMENTATION == AOFX_IMPLEMENTATION_CS )

//==================================================================================================
// AO : Performs valley detection in Camera space, and uses the valley angle to scale occlusion.
//==================================================================================================
float kernelHDAO(vec3 centerPosition, vec2 screenCoord, ivec2 cacheCoord, uint randomIndex, uvec2 layerIdx, uint layerIndex)
{
  if ( centerPosition.z > g_cbAO.m_ViewDistanceDiscard ) return 1.0;

  float centerDistance = length(centerPosition);
  float  occlusion = 0.0f;

#if ( AOFX_TAP_TYPE == AOFX_TAP_TYPE_RANDOM_CB )
  uint randomInput = randomIndex;
#elif ( AOFX_TAP_TYPE == AOFX_TAP_TYPE_RANDOM_SRV )
  uint randomInput = randomIndex * 32;
#endif

  for ( uint uValley = 0; uValley < NUM_VALLEYS; uValley++ )
  {
    vec3 direction[2];
    vec3 position[2];
    float  distance[2];
    vec2 distanceDelta;
    vec2 compare;
    float  directionDot;

#if ( AOFX_TAP_TYPE == AOFX_TAP_TYPE_RANDOM_CB )
    ivec2 samplePattern = g_cbSamplePattern[randomInput][uValley].xy;
#elif ( AOFX_TAP_TYPE == AOFX_TAP_TYPE_RANDOM_SRV )
    ivec2 samplePattern = g_b1dSamplePattern.Load(randomInput + uValley).xy;
#else // ( AOFX_TAP_TYPE == AOFX_TAP_TYPE_FIXED )
    ivec2 samplePattern = g_SamplePattern[uValley].xy;
#endif // ( AOFX_TAP_TYPE == AOFX_TAP_TYPE_RANDOM_CB )

    // Sample
    position[0] = fetchPositionFromCache(screenCoord + samplePattern, uvec2(cacheCoord + samplePattern), ivec2(layerIdx));
    position[1] = fetchPositionFromCache(screenCoord - samplePattern, uvec2(cacheCoord - samplePattern), ivec2(layerIdx));

    // Compute distances
    distance[0] = length(position[0]);
    distance[1] = length(position[1]);

    // Detect valleys
    distanceDelta = centerDistance.xx - vec2(distance[0], distance[1]);
    compare = clamp((g_cbAO.m_RejectRadius.xx - distanceDelta) * (g_cbAO.m_RecipFadeOutDist), 0.f, 1.f);
    compare = mix(vec2(0.0f), compare, greaterThan(distanceDelta, g_cbAO.m_AcceptRadius.xx));

    // Compute dot product, to scale occlusion
    direction[0] = normalize(centerPosition - position[0]);
    direction[1] = normalize(centerPosition - position[1]);
    directionDot = clamp(dot(direction[0], direction[1]) + 0.9f, 0.f, 1.f) * 1.2f;

    // Accumulate weighted occlusion
    occlusion += compare.x * compare.y * directionDot * directionDot * directionDot;
  }

  // Finally calculate the AO occlusion value
  occlusion /= NUM_VALLEYS;
  occlusion *= g_cbAO.m_LinearIntensity;
  occlusion = 1.0f - clamp(occlusion, 0.f, 1.f);

  float weight = clamp((centerPosition.z - g_cbAO.m_ViewDistanceFade) / g_cbAO.m_FadeIntervalLength, 0.f, 1.f);
  return mix(occlusion, 1.0f, weight);
}