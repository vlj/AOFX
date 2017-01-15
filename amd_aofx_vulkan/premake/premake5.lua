_AMD_LIBRARY_NAME = "AOFX_VK"
_AMD_LIBRARY_NAME_ALL_CAPS = string.upper(_AMD_LIBRARY_NAME)

-- Set _AMD_LIBRARY_NAME before including amd_premake_util.lua
dofile ("../../premake/amd_premake_util.lua")

workspace ("AMD_" .. _AMD_LIBRARY_NAME)
   configurations { "DLL_Debug", "DLL_Release", "Lib_Debug", "Lib_Release", "DLL_Release_MT" }
   platforms { "Win32", "x64" }
   location "../build"
   filename ("AMD_" .. _AMD_LIBRARY_NAME .. _AMD_VS_SUFFIX)
   startproject ("AMD_" .. _AMD_LIBRARY_NAME)

   filter "platforms:Win32"
      system "Windows"
      architecture "x86"

   filter "platforms:x64"
      system "Windows"
      architecture "x64"

externalproject "AMD_LIB_Minimal"
   kind "StaticLib"
   language "C++"
   location "../../amd_lib/shared/d3d11/build"
   filename ("AMD_LIB_Minimal" .. _AMD_VS_SUFFIX)
   uuid "0D2AEA47-7909-69E3-8221-F4B9EE7FCF44"
   configmap {
      ["DLL_Debug"] = "Debug",
      ["DLL_Release"] = "Release",
      ["Lib_Debug"] = "Debug",
      ["Lib_Release"] = "Release",
      ["DLL_Release_MT"] = "Release_MT" }

project ("AMD_" .. _AMD_LIBRARY_NAME)
   language "C++"
   location "../build"
   filename ("AMD_" .. _AMD_LIBRARY_NAME .. _AMD_VS_SUFFIX)
   uuid "21473363-E6A1-4460-8454-0F4C411B5B3D"
   targetdir "../lib/%{_AMD_LIBRARY_DIR_LAYOUT}"
   objdir "../build/%{_AMD_LIBRARY_DIR_LAYOUT}"
   warnings "Extra"
   exceptionhandling "Off"
   rtti "Off"

   -- Specify WindowsTargetPlatformVersion here for VS2015
   windowstarget (_AMD_WIN_SDK_VERSION)
   defines { "AMD_TRESSFX_VULKAN=1" }

   files { "../inc/**.h", "../src/**.h", "../src/**.cpp", "../src/Shaders/**.hlsl" }
   includedirs { "../inc", "../../amd_lib/shared/common/inc", "../../amd_lib/shared/d3d11/inc" }
   links { "AMD_LIB_Minimal" }

   filter "configurations:DLL_*"
      kind "SharedLib"
      defines { "_USRDLL", "AMD_%{_AMD_LIBRARY_NAME_ALL_CAPS}_COMPILE_DYNAMIC_LIB=1" }
      -- Copy DLL and import library to the lib directory
      postbuildcommands { amdLibPostbuildCommands() }
      postbuildmessage "Copying build output to lib directory..."

   filter "configurations:Lib_*"
      kind "StaticLib"
      defines { "_LIB", "AMD_%{_AMD_LIBRARY_NAME_ALL_CAPS}_COMPILE_DYNAMIC_LIB=0" }

   filter "configurations:*_Debug"
      defines { "WIN32", "_DEBUG", "_WINDOWS", "_WIN32_WINNT=0x0601" }
      flags { "Symbols", "FatalWarnings", "Unicode" }
      -- add "d" to the end of the library name for debug builds
      targetsuffix "d"

   filter "configurations:*_Release"
      defines { "WIN32", "NDEBUG", "_WINDOWS", "_WIN32_WINNT=0x0601" }
      flags { "FatalWarnings", "Unicode" }
      optimize "On"

   filter "configurations:DLL_Release_MT"
      defines { "WIN32", "NDEBUG", "_WINDOWS", "_WIN32_WINNT=0x0601" }
      flags { "FatalWarnings", "Unicode" }
      -- link against the static runtime to avoid introducing a dependency
      -- on the particular version of Visual Studio used to build the DLLs
      flags { "StaticRuntime" }
      optimize "On"

   filter "action:vs*"
      -- specify exception handling model for Visual Studio to avoid
      -- "'noexcept' used with no exception handling mode specified" 
      -- warning in vs2015
      buildoptions { "/EHsc" }

   filter "platforms:Win32"
      targetname "%{_AMD_LIBRARY_PREFIX}%{_AMD_LIBRARY_NAME}_x86"

   filter "platforms:x64"
      targetname "%{_AMD_LIBRARY_PREFIX}%{_AMD_LIBRARY_NAME}_x64"
