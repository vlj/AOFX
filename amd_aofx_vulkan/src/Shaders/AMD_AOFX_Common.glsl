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

#ifndef AMD_AOFX_COMMON_HLSL
#define AMD_AOFX_COMMON_HLSL

//======================================================================================================
// AO parameter constants
//======================================================================================================
#define AO_GROUP_THREAD_DIM                      ( 32 )                      // 32 * 32 = 1024 threads
#define AO_GROUP_TEXEL_DIM                       ( AO_GROUP_THREAD_DIM * 2 ) // 32 * 2 = 64 ; 64 x 64 is the size of loaded tile
#define AO_GROUP_TEXEL_OVERLAP                   ( AO_GROUP_THREAD_DIM / 2 ) // overlap is 16 texels

#define AO_ULTRA_SAMPLE_COUNT                    32
#define AO_HIGH_SAMPLE_COUNT                     24
#define AO_MEDIUM_SAMPLE_COUNT                   16
#define AO_LOW_SAMPLE_COUNT                      8

#define AOFX_NORMAL_OPTION_NONE                  0
#define AOFX_NORMAL_OPTION_READ_FROM_SRV         1

#define AOFX_TAP_TYPE_FIXED                      0
#define AOFX_TAP_TYPE_RANDOM_CB                  1
#define AOFX_TAP_TYPE_RANDOM_SRV                 2

#define AOFX_IMPLEMENTATION_CS                   0
#define AOFX_IMPLEMENTATION_PS                   1

#define AO_STORE_XY_LDS                          1

#define AO_RANDOM_TAPS_COUNT                     64 

#ifndef AOFX_IMPLEMENTATION
#   define AOFX_IMPLEMENTATION                   AOFX_IMPLEMENTATION_CS
#endif

#ifndef AOFX_NORMAL_OPTION
#   define AOFX_NORMAL_OPTION                    AOFX_NORMAL_OPTION_NONE
#endif

#ifndef AOFX_TAP_TYPE
#   define AOFX_TAP_TYPE                         AOFX_TAP_TYPE_FIXED
#endif

#ifndef AOFX_MSAA_LEVEL
#   define AOFX_MSAA_LEVEL                       1
#endif

#if (AOFX_NORMAL_OPTION == AOFX_NORMAL_OPTION_NONE)
# define AO_INPUT_TYPE                           float
#elif (AOFX_NORMAL_OPTION == AOFX_NORMAL_OPTION_READ_FROM_SRV)
# define AO_INPUT_TYPE                           float4
#endif

#ifndef AO_DEINTERLEAVE_FACTOR 
# define AO_DEINTERLEAVE_FACTOR                  4
#endif

#define AO_DEINTERLEAVE_FACTOR_SQR               (AO_DEINTERLEAVE_FACTOR*AO_DEINTERLEAVE_FACTOR)

#define MUL_AO_DEINTERLEAVE_FACTOR(coord)       ((coord) * AO_DEINTERLEAVE_FACTOR)    
#define DIV_AO_DEINTERLEAVE_FACTOR(coord)       ((coord) / AO_DEINTERLEAVE_FACTOR)  
#define MOD_AO_DEINTERLEAVE_FACTOR(coord)       ((coord) % AO_DEINTERLEAVE_FACTOR) 

//======================================================================================================
// AO structures
//======================================================================================================

struct AO_Data
{
  uvec2                                          m_OutputSize;
  vec2                                           m_OutputSizeRcp;
  uvec2                                          m_InputSize;                 // size (xy), inv size (zw)
  vec2                                           m_InputSizeRcp;                  // size (xy), inv size (zw)

  float                                          m_CameraQ;                    // far / (far - near)
  float                                          m_CameraQTimesZNear;          // cameraQ * near
  float                                          m_CameraTanHalfFovHorizontal; // Tan Horiz and Vert FOV
  float                                          m_CameraTanHalfFovVertical;

  float                                          m_RejectRadius;
  float                                          m_AcceptRadius;
  float                                          m_RecipFadeOutDist;
  float                                          m_LinearIntensity;

  float                                          m_NormalScale;
  float                                          m_MultiResLayerScale;
  float                                          m_ViewDistanceFade;
  float                                          m_ViewDistanceDiscard;

  float                                          m_FadeIntervalLength;
  vec3                                           _pad;
};

struct AO_InputData
{
  uvec2                                          m_OutputSize;
  vec2                                           m_OutputSizeRcp;
  uvec2                                          m_InputSize;                 // size (xy), inv size (zw)
  vec2                                           m_InputSizeRcp;              // size (xy), inv size (zw)

  float                                          m_ZFar;
  float                                          m_ZNear;
  float                                          m_CameraQ;                    // far / (far - near)
  float                                          m_CameraQTimesZNear;          // cameraQ * near
  float                                          m_CameraTanHalfFovHorizontal; // Tan Horiz and Vert FOV
  float                                          m_CameraTanHalfFovVertical;

  float                                          m_DepthUpsampleThreshold;
  float                                          m_NormalScale;

  float                                          m_Scale;
  float                                          m_ScaleRcp;
  float                                          m_ViewDistanceFade;
  float                                          m_ViewDistanceDiscard;
};

//======================================================================================================
// AO constant buffers, samplers and textures
//======================================================================================================

layout(set = 0, binding = 0) uniform sampler     g_ssPointClamp;
layout(set = 0, binding = 1) uniform sampler     g_ssLinearClamp;
layout(set = 0, binding = 2) uniform sampler     g_ssPointWrap;
layout(set = 0, binding = 3) uniform sampler     g_ssLinearWrap;

#if (AOFX_MSAA_LEVEL == 1)
layout(set = 1, binding = 4) uniform texture2D   g_t2dDepth;
layout(set = 1, binding = 5) uniform texture2D   g_t2dNormal;
#else
Texture2DMS< float, AOFX_MSAA_LEVEL >              g_t2dDepth                    : register( t0 );
Texture2DMS< float4, AOFX_MSAA_LEVEL >             g_t2dNormal                   : register( t1 );
#endif

layout(set = 1, binding = 6) uniform samplerBuffer  g_b1dSamplePattern;

#if (AO_DEINTERLEAVE_FACTOR == 1)
layout(set = 1, binding = 7) uniform texture2D   g_t2dInput;
#else
layout(set = 1, binding = 8) uniform texture2DArray g_t2daInput;
#endif

layout(set = 2, binding = 9, std140) uniform     CB_AO_DATA
{
  AO_Data                                        g_cbAO;
};

layout(set = 2, binding = 10, std140) uniform    CB_SAMPLE_PATTERN
{
  ivec4                                           g_cbSamplePattern[64][32];
};

#if defined( ULTRA_SAMPLES )

# define NUM_VALLEYS                             AO_ULTRA_SAMPLE_COUNT
const ivec2                                g_SamplePattern[NUM_VALLEYS] =
{
  {0, -9}, {4, -9}, {2, -6}, {6, -6},
  {0, -3}, {4, -3}, {8, -3}, {2, 0},
  {6, 0}, {9, 0}, {4, 3}, {8, 3},
  {2, 6}, {6, 6}, {9, 6}, {4, 9},
  {10, 0}, {-12, 12}, {9, -14}, {-8, -6},
  {11, -7}, {-9, 1}, {-2, -13}, {-7, -3},
  {4, 7}, {3, -13}, {12, 3}, {-12, 8},
  {-10, 13}, {12, 1}, {9, 13}, {0, -5},
};

#elif defined( HIGH_SAMPLES )

# define NUM_VALLEYS                             AO_HIGH_SAMPLE_COUNT
const ivec2                                g_SamplePattern[NUM_VALLEYS] =
{
  {0, -9}, {4, -9}, {2, -6}, {6, -6},
  {0, -3}, {4, -3}, {8, -3}, {2, 0},
  {6, 0}, {9, 0}, {4, 3}, {8, 3},
  {2, 6}, {6, 6}, {9, 6}, {4, 9},
  {10, 0}, {-12, 12}, {9, -14}, {-8, -6},
  {11, -7}, {-9, 1}, {-2, -13}, {-7, -3},
};

#elif defined( MEDIUM_SAMPLES )

# define NUM_VALLEYS                             AO_MEDIUM_SAMPLE_COUNT
const ivec2                                g_SamplePattern[NUM_VALLEYS] =
{
  {0, -9}, {4, -9}, {2, -6}, {6, -6},
  {0, -3}, {4, -3}, {8, -3}, {2, 0},
  {6, 0}, {9, 0}, {4, 3}, {8, 3},
  {2, 6}, {6, 6}, {9, 6}, {4, 9},
};

#else //if defined( LOW_SAMPLES )

# define NUM_VALLEYS                             AO_LOW_SAMPLE_COUNT
const ivec2                                g_SamplePattern[NUM_VALLEYS] =
{
  {0, -9}, {2, -6}, {0, -3}, {8, -3},
  {6, 0}, {4, 3}, {2, 6}, {9, 6},
};

#endif // ULTRA_SAMPLES

//======================================================================================================
// AO packing function
//======================================================================================================

uint normalToUint16(vec3 unitNormal, out int zSign)
{
  zSign = int(sign(unitNormal.z));

  int x = int((unitNormal.x * 0.5 + 0.5) * 255.0f);
  int y = int((unitNormal.y * 0.5 + 0.5) * 255.0f);

  int result = (x & 0x000000FF) | ((y & 0x000000FF) << 8);

  return result;
}

vec3 uint16ToNormal(uint normal, int zSign)
{
  vec3 result;

  int x = int(normal & 0x000000FF);
  int y = int((normal & 0x0000FF00) >> 8);

  result.x = ((x / 255.0f) - 0.5f) * 2.0f;
  result.y = ((y / 255.0f) - 0.5f) * 2.0f;

  result.z = zSign * sqrt(1 - result.x * result.x - result.y * result.y);

  return result;
}

uint f32tof16(float v)
{
  return floatBitsToUint(unpackHalf2x16(floatBitsToUint(v)).x);
}

float f16tof32(uint v)
{
  return  packHalf2x16(vec2(v)) & 0xFFFF;
}

uint depthToUint16(float linearDepth)
{
  return f32tof16(linearDepth);
}

float uint16ToDepth(uint depth)
{
  return f16tof32(depth);
}

// Packs a float2 to a unit
uint float2ToUint32(vec2 f2Value)
{
  uint uRet = 0;

  uRet = (f32tof16(f2Value.x)) + (f32tof16(f2Value.y) << 16);

  return uRet;
}

uint int2ToUint(ivec2 i2Value)
{
  uint uRet = 0;

  uRet = (i2Value.x) + (i2Value.y << 16);

  return uRet;
}

// Unpacks a uint to a float2
vec2 uintToFloat2(uint uValue)
{
  return vec2(f16tof32(uValue), f16tof32(uValue >> 16));
}

ivec2 uintToInt2(uint uValue)
{
  return ivec2(uValue & 65536, uValue >> 16);
}

vec3 loadCameraSpacePositionT2D( vec2 screenCoord, ivec2 layerIdx )
{

#if (AO_DEINTERLEAVE_FACTOR == 1)
  AO_INPUT_TYPE aoInput = g_t2dInput.SampleLevel(g_ssPointClamp, screenCoord.xy * g_cbAO.m_OutputSizeRcp, 0.0f);
#else //  (AO_DEINTERLEAVE_FACTOR == 1)
  int layer = layerIdx.x + MUL_AO_DEINTERLEAVE_FACTOR(layerIdx.y);
  AO_INPUT_TYPE aoInput = textureLod(sampler2DArray(g_t2daInput, g_ssPointClamp), vec3((screenCoord.xy + vec2(0.5, 0.5)) * g_cbAO.m_OutputSizeRcp, layer), 0.0f).x;
#endif //  (AO_DEINTERLEAVE_FACTOR == 1)

#if (AOFX_NORMAL_OPTION == AOFX_NORMAL_OPTION_NONE)

  float camera_z = aoInput.x;

# if (AO_DEINTERLEAVE_FACTOR == 1)
  vec2 camera = screenCoord.xy * g_cbAO.m_InputSizeRcp - vec2(1.0f, 1.0f);
# else //  (AO_DEINTERLEAVE_FACTOR == 1)
  vec2 camera = (MUL_AO_DEINTERLEAVE_FACTOR(screenCoord.xy) + layerIdx + vec2(0.5, 0.5)) * g_cbAO.m_InputSizeRcp - vec2(1.0f, 1.0f);
# endif //  (AO_DEINTERLEAVE_FACTOR == 1)

  camera.x = camera.x * camera_z * g_cbAO.m_CameraTanHalfFovHorizontal;
  camera.y = camera.y * camera_z * -g_cbAO.m_CameraTanHalfFovVertical;

  vec3 position = vec3(camera.xy, camera_z);

#elif (AOFX_NORMAL_OPTION == AOFX_NORMAL_OPTION_READ_FROM_SRV)

  vec3 position = aoInput.yzw;

#endif

  return position;
}

float loadCameraSpaceDepthT2D( vec2 uv, float cameraQ, float cameraZNearXQ )
{

  float depth = textureLod(sampler2D(g_t2dDepth, g_ssPointClamp), uv, 0.0f).x;

  float camera_z = -cameraZNearXQ / ( depth - cameraQ );

  return camera_z;
}

#endif // AMD_AOFX_COMMON_HLSL