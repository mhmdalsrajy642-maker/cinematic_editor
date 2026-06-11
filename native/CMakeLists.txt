// native/CMakeLists.txt
# CMake build configuration for Cinematic Editor native bridge
# Builds the FFI library exposing C++ functions to Dart

cmake_minimum_required(VERSION 3.20)
project(cinematic_bridge C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ====================================================
# Platform Detection
# ====================================================

if(ANDROID)
    message(STATUS "Building for Android")
    set(PLATFORM_NAME "android")
elseif(APPLE)
    if(IOS)
        message(STATUS "Building for iOS")
        set(PLATFORM_NAME "ios")
    else()
        message(STATUS "Building for macOS")
        set(PLATFORM_NAME "macos")
    endif()
elseif(UNIX)
    message(STATUS "Building for Linux")
    set(PLATFORM_NAME "linux")
elseif(WIN32)
    message(STATUS "Building for Windows")
    set(PLATFORM_NAME "windows")
else()
    message(FATAL_ERROR "Unsupported platform")
endif()

# ====================================================
# Source Files
# ====================================================

set(SOURCES
    cpp/engine/engine.cc
    cpp/ffmpeg_bridge/ffmpeg_bridge.cc
)

set(HEADERS
    cpp/include/cinematic_bridge.h
)

# ====================================================
# Library Target
# ====================================================

if(ANDROID)
    # Build as shared library for Android
    add_library(cinematic_bridge SHARED ${SOURCES} ${HEADERS})
elseif(APPLE)
    if(IOS)
        # Build as static library for iOS
        add_library(cinematic_bridge STATIC ${SOURCES} ${HEADERS})
    else()
        # Build as framework for macOS
        add_library(cinematic_bridge SHARED ${SOURCES} ${HEADERS})
    endif()
else()
    # Build as shared library for Linux/Windows
    add_library(cinematic_bridge SHARED ${SOURCES} ${HEADERS})
endif()

# ====================================================
# Include Directories
# ====================================================

target_include_directories(cinematic_bridge PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/include
)

# ====================================================
# Compiler Flags
# ====================================================

if(MSVC)
    # Visual Studio
    target_compile_options(cinematic_bridge PRIVATE /W4 /WX)
    target_compile_options(cinematic_bridge PRIVATE /fp:fast)
else()
    # GCC/Clang
    target_compile_options(cinematic_bridge PRIVATE -Wall -Wextra -Werror)
    target_compile_options(cinematic_bridge PRIVATE -ffast-math)
    target_compile_options(cinematic_bridge PRIVATE -fvisibility=hidden)
endif()

# ====================================================
# Optimization Flags
# ====================================================

if(CMAKE_BUILD_TYPE STREQUAL "Release")
    message(STATUS "Release build - enabling optimizations")
    if(MSVC)
        target_compile_options(cinematic_bridge PRIVATE /O2)
    else()
        target_compile_options(cinematic_bridge PRIVATE -O3)
    endif()
endif()

# ====================================================
# Optional: FFmpeg Integration (Future)
# ====================================================

# Uncomment when FFmpeg integration is ready:
# find_package(FFmpeg REQUIRED COMPONENTS avformat avcodec avutil)
# target_link_libraries(cinematic_bridge PRIVATE FFmpeg::FFmpeg)

# ====================================================
# Optional: GPU Acceleration (Future)
# ====================================================

# For NVIDIA GPU acceleration:
# find_package(CUDA)
# if(CUDA_FOUND)
#     target_compile_options(cinematic_bridge PRIVATE -DENABLE_CUDA)
#     target_link_libraries(cinematic_bridge PRIVATE ${CUDA_LIBRARIES})
# endif()

# ====================================================
# Installation
# ====================================================

if(ANDROID)
    # Android NDK install (handled by Flutter)
    install(TARGETS cinematic_bridge LIBRARY DESTINATION lib)
elseif(APPLE)
    if(IOS)
        # iOS install
        install(TARGETS cinematic_bridge ARCHIVE DESTINATION lib)
    else()
        # macOS install
        install(TARGETS cinematic_bridge LIBRARY DESTINATION lib)
    endif()
else()
    # Linux/Windows install
    install(TARGETS cinematic_bridge LIBRARY DESTINATION lib)
endif()

# ====================================================
# Build Information
# ====================================================

message(STATUS "Cinematic Bridge Configuration:")
message(STATUS "  Platform: ${PLATFORM_NAME}")
message(STATUS "  Build Type: ${CMAKE_BUILD_TYPE}")
message(STATUS "  C++ Standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "  Compiler: ${CMAKE_CXX_COMPILER_ID}")
