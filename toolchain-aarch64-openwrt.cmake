# CMake toolchain file for cross-compiling to aarch64 OpenWrt (musl libc)
# Usage:
#   cmake -B build \
#     -DCMAKE_TOOLCHAIN_FILE=toolchain-aarch64-openwrt.cmake \
#     -DLIBNL_TINY_PATH=/path/to/sdk/staging_dir/target-aarch64.../usr/lib \
#     -DLIBNL_TINY_INCLUDE=/path/to/sdk/staging_dir/target-aarch64.../usr/include/libnl-tiny
#
# Required environment variables (set by the CI workflow):
#   OPENWRT_CC    - path to aarch64-openwrt-linux-gcc
#   OPENWRT_CXX   - path to aarch64-openwrt-linux-g++
#   OPENWRT_SYSROOT - path to SDK staging_dir/target-aarch64_cortex-a53_musl

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(CMAKE_C_COMPILER   $ENV{OPENWRT_CC})
set(CMAKE_CXX_COMPILER $ENV{OPENWRT_CXX})

if(DEFINED ENV{OPENWRT_SYSROOT})
  set(CMAKE_SYSROOT $ENV{OPENWRT_SYSROOT})
  set(CMAKE_FIND_ROOT_PATH $ENV{OPENWRT_SYSROOT})
endif()

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
