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


#include "../../../AMD_LIB/src/Shaders/AMD_FullscreenPass.hlsl"

// Samplers
SamplerState        g_SamplePoint                          : register( s0 );
SamplerState        g_SampleLinear                         : register( s1 );

//=================================================================================================================================
// Render Scene Color multipled by AO Result
//=================================================================================================================================
Texture2D      g_T2D_RENDER_SCENE_WITH_AO_Scene          :  register (t0);
Texture2D      g_T2D_RENDER_SCENE_WITH_AO_AO             :  register (t1);

float4 PS_RenderSceneWithAO( PS_FullscreenPassInput I ) : SV_Target
{
  float4 color = g_T2D_RENDER_SCENE_WITH_AO_Scene.Sample( g_SamplePoint, I.f2TexCoord );
  float  ao    = g_T2D_RENDER_SCENE_WITH_AO_AO.Sample( g_SamplePoint, I.f2TexCoord ).x;

  return float4(color.xyz*ao, color.w);
}

//=================================================================================================================================
// EOF
//=================================================================================================================================









