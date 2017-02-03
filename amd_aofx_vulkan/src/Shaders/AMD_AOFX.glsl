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
#version 450
#include "AMD_AOFX_Common.glsl"

//==================================================================================================
// AO UAVs, Textures & Samplers
//==================================================================================================
layout(r32f) writeonly uniform image2D                              g_t2dOutput;


#include "AMD_AOFX_Kernel.glsl"

#if ( AOFX_IMPLEMENTATION == AOFX_IMPLEMENTATION_CS )

//==================================================================================================
// AO CS: Loads an overlapping tile of texels from the pre-processed depth buffer 
// It then converts depth into camera XYZ 
// If normals are used, the convertion from depth -> camera XYZ happens at a preprocess step
// and camera XYZ is additionally displaced by the normal vector 
//==================================================================================================
layout(local_size_x = AO_GROUP_THREAD_DIM, local_size_y = AO_GROUP_THREAD_DIM) in;
void csAmbientOcclusion()
{
  uvec3 groupIdx = gl_WorkGroupID;
  uvec3 threadIdx = gl_LocalInvocationID;
  //                      uint  threadIndex : SV_GroupIndex,
  uvec3 dispatchIdx = gl_GlobalInvocationID;

  vec2 baseCoord = dispatchIdx.xy + vec2(0.5f, 0.5f);

  vec2 screenCoord = baseCoord + vec2(-AO_GROUP_TEXEL_OVERLAP, -AO_GROUP_TEXEL_OVERLAP);
  vec3 position = loadCameraSpacePositionT2D(screenCoord, ivec2(0, 0));
  storePositionInCache(position, threadIdx.xy + ivec2(AO_GROUP_THREAD_DIM * 0, AO_GROUP_THREAD_DIM * 0));

  screenCoord = baseCoord + vec2(-AO_GROUP_TEXEL_OVERLAP, AO_GROUP_TEXEL_OVERLAP);
  position = loadCameraSpacePositionT2D(screenCoord, ivec2(0, 0));
  storePositionInCache(position, threadIdx.xy + ivec2(AO_GROUP_THREAD_DIM * 0, AO_GROUP_THREAD_DIM * 1));

  screenCoord = baseCoord + vec2(AO_GROUP_TEXEL_OVERLAP, -AO_GROUP_TEXEL_OVERLAP);
  position = loadCameraSpacePositionT2D(screenCoord, ivec2(0, 0));
  storePositionInCache(position, threadIdx.xy + ivec2(AO_GROUP_THREAD_DIM * 1, AO_GROUP_THREAD_DIM * 0));

  screenCoord = baseCoord + vec2(AO_GROUP_TEXEL_OVERLAP, AO_GROUP_TEXEL_OVERLAP);
  position = loadCameraSpacePositionT2D(screenCoord, ivec2(0, 0));
  storePositionInCache(position, threadIdx.xy + ivec2(AO_GROUP_THREAD_DIM * 1, AO_GROUP_THREAD_DIM * 1));

  groupMemoryBarrier();

  if ( (dispatchIdx.x < g_cbAO.m_OutputSize.x) && (dispatchIdx.y < g_cbAO.m_OutputSize.y) )
  {
    ivec2 cacheCoord = ivec2(threadIdx.xy) + ivec2(AO_GROUP_TEXEL_OVERLAP, AO_GROUP_TEXEL_OVERLAP);
    screenCoord = baseCoord;
    position = fetchPositionFromCache(screenCoord.xy, cacheCoord, ivec2(0, 0));
    uint randomIndex = (dispatchIdx.x * dispatchIdx.y) % AO_RANDOM_TAPS_COUNT;

    float ambientOcclusion = kernelHDAO(position, screenCoord.xy, cacheCoord, randomIndex, uvec2(0, 0), 0);

    imageStore(g_t2dOutput, ivec2(dispatchIdx.xy), vec4(ambientOcclusion));
  }
}

#elif ( AOFX_IMPLEMENTATION == AOFX_IMPLEMENTATION_PS )

#include "../../../amd_lib/shared/d3d11/src/Shaders/AMD_FullscreenPass.hlsl"

void psAmbientOcclusion ( PS_FullscreenInput In )
{
  uint2  dispatchIdx = uint2(In.position.xy);
  float2 screenCoord = In.position.xy;
  float3 position = fetchPositionFromCache(screenCoord, uint2(0, 0), int2(0, 0));
  uint randomIndex = (dispatchIdx.x * dispatchIdx.y) % AO_RANDOM_TAPS_COUNT;

  float ambientOcclusion = kernelHDAO(position, screenCoord.xy, uint2(0, 0), randomIndex, uint2(0, 0), 0);

  if ( (dispatchIdx.x < g_cbAO.m_OutputSize.x) && 
       (dispatchIdx.y < g_cbAO.m_OutputSize.y) )
    g_t2dOutput[dispatchIdx] = ambientOcclusion;
}

#endif // AOFX_IMPLEMENTATION

//======================================================================================================
// EOF
//======================================================================================================