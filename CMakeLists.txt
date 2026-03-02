cmake_minimum_required(VERSION 3.10)
project(CSIdump)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED True)

# Cross-compiler: set via cmake -DCMAKE_CXX_COMPILER=... or toolchain file.
# For CI, use the toolchain-aarch64-openwrt.cmake toolchain file.
# For local development, uncomment and adjust one of the lines below:
#set(CMAKE_CXX_COMPILER aarch64-linux-gnu-g++)
#set(CMAKE_CXX_COMPILER /path/to/openwrt-sdk/staging_dir/toolchain-aarch64_cortex-a53_gcc-13.3.0_musl/bin/aarch64-openwrt-linux-g++)

set(SOURCES
  parsers/parser_mt76.cpp
  wifi_drv_api/mt76_api.cpp
  motion_detector.cpp
  md.cpp
)

include_directories(${CMAKE_SOURCE_DIR})

add_executable(CSIdump ${SOURCES} main.cpp)

# libnl-tiny paths: set via cmake -DLIBNL_TINY_PATH=... -DLIBNL_TINY_INCLUDE=...
# For CI, these are passed automatically by the build workflow.
# For local development, set these to your local libnl-tiny build/install paths.
if(NOT DEFINED LIBNL_TINY_PATH)
  set(LIBNL_TINY_PATH /data/mediatek/leaks/meta-gl-motion-detection/recipes-ccsp/hal/files/libnl-tiny_bin/usr/local/lib/)
endif()
if(NOT DEFINED LIBNL_TINY_INCLUDE)
  set(LIBNL_TINY_INCLUDE /data/mediatek/leaks/meta-gl-motion-detection/recipes-ccsp/hal/files/libnl-tiny_bin/usr/local/include/libnl-tiny/)
endif()

# Must be set before find_library so only the static archive is matched.
# NO_DEFAULT_PATH + NO_CMAKE_FIND_ROOT_PATH prevent cross-compile sysroot
# mangling of the explicitly supplied absolute path.
set(CMAKE_FIND_LIBRARY_SUFFIXES ".a")
find_library(LIBNL_TINY nl-tiny
  PATHS ${LIBNL_TINY_PATH}
  NO_DEFAULT_PATH
  NO_CMAKE_FIND_ROOT_PATH
)
if(NOT LIBNL_TINY)
  message(FATAL_ERROR "libnl-tiny.a not found in ${LIBNL_TINY_PATH}. "
    "Pass -DLIBNL_TINY_PATH=<dir> pointing to the directory that contains libnl-tiny.a.")
endif()

include_directories(${LIBNL_TINY_INCLUDE})

add_compile_options(-Wall -Wextra)

# Static linking configuration
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -static")

find_package(Threads REQUIRED)
target_link_libraries(CSIdump PRIVATE Threads::Threads ${LIBNL_TINY} -lgcc_eh -lgcc -static-libgcc -static-libstdc++)
