# MIT License
#
# Copyright (c) 2018-2022 The ViaDuck Project
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

# build icu locally

# includes
include(ProcessorCount)
include(ExternalProject)
include(ByproductsICU)

# find programs
find_program(MAKE_PROGRAM make)

# used to apply patches to ICU
find_program(PATCH_PROGRAM patch)
if (NOT PATCH_PROGRAM)
    message(FATAL_ERROR "Cannot find patch utility.")
endif()

# set variables
ProcessorCount(NUM_JOBS)

# try to compile icu
if (NOT ICU_BUILD_VERSION)
    message(FATAL_ERROR "Missing ICU_BUILD_VERSION")
endif()
string(REPLACE "." "_" ICU_URL_VERSION ${ICU_BUILD_VERSION})
set(ICU_URL https://mirror.viaduck.org/icu/icu4c-${ICU_URL_VERSION}-src.tgz)

if (ICU_BUILD_HASH)
    set(ICU_CHECK_HASH EXPECTED_HASH SHA256=${ICU_BUILD_HASH})
endif()

# download and unpack if needed
if (EXISTS ${CMAKE_CURRENT_BINARY_DIR}/icu)
    message(STATUS "Using existing ICU source")
else()
    file(DOWNLOAD ${ICU_URL} ${CMAKE_CURRENT_BINARY_DIR}/icu_src.tgz SHOW_PROGRESS STATUS ICU_DL_STATUS ${ICU_CHECK_HASH})

    # check download result
    list(GET ICU_DL_STATUS 0 ICU_DL_STATUS_CODE)
    if (NOT ICU_DL_STATUS_CODE EQUAL 0)
        message(FATAL_ERROR "ICU download failed with code: ${ICU_DL_STATUS_CODE}")
    endif()

    execute_process(COMMAND ${CMAKE_COMMAND} -E tar x ${CMAKE_CURRENT_BINARY_DIR}/icu_src.tgz WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
endif()

# common configuration options for host and cross build
set(ICU_CFG --enable-static ${ICU_CFG_OPTIONS})
if (NOT ICU_DISABLE_RPATH)
    list(APPEND ICU_CFG --enable-rpath)
endif()

# if we are actually building for host, use cmake params for it
if (NOT ICU_CROSS_ARCH)
    set(HOST_CFLAGS "${CMAKE_C_FLAGS}")
    set(HOST_CXXFLAGS "${CMAKE_CXX_FLAGS}")
    set(HOST_CC "${CMAKE_C_COMPILER}")
    set(HOST_CXX "${CMAKE_CXX_COMPILER}")
    set(HOST_LDFLAGS "${CMAKE_MODULE_LINKER_FLAGS}")
    set(HOST_CFG ${ICU_CFG})
    
    set(HOST_ENV_CMAKE ${CMAKE_COMMAND} -E env
            CC=${HOST_CC}
            CXX=${HOST_CXX}
            CFLAGS=${HOST_CFLAGS}
            CXXFLAGS=${HOST_CXXFLAGS}
            LDFLAGS=${HOST_LDFLAGS}
    )
    
    # predict host libraries
    GetICUByproducts(${CMAKE_CURRENT_BINARY_DIR}/icu_host ICU_LIBRARIES ICU_LIBRARY_FILES ICU_INCLUDE_DIRS)
endif()

ExternalProject_Add(
        icu_host
        SOURCE_DIR ${CMAKE_CURRENT_BINARY_DIR}/icu
        BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/icu_host-build
        PATCH_COMMAND ${PATCH_PROGRAM} -p1 --forward -r - < ${CMAKE_CURRENT_SOURCE_DIR}/patches/0010-fix-pkgdata-suffix.patch || true
        COMMAND ${PATCH_PROGRAM} -p1 --forward -r - < ${CMAKE_CURRENT_SOURCE_DIR}/patches/0023-remove-soname-version.patch || true
        CONFIGURE_COMMAND ${HOST_ENV_CMAKE} <SOURCE_DIR>/source/configure --prefix=${CMAKE_CURRENT_BINARY_DIR}/icu_host --libdir=${CMAKE_CURRENT_BINARY_DIR}/icu_host/lib/ ${HOST_CFG}
        BUILD_COMMAND ${HOST_ENV_CMAKE} ${MAKE_PROGRAM} -j ${NUM_JOBS}
        BUILD_BYPRODUCTS ${ICU_LIBRARY_FILES}
        INSTALL_COMMAND ${HOST_ENV_CMAKE} ${MAKE_PROGRAM} install
)
set(ICU_TARGET icu_host)
add_dependencies(icu icu_host)

if (ICU_CROSS_ARCH)
    if (ANDROID)
        set(CROSS_INCLUDES "")
        set(CROSS_LIBS "")
    
        # copy over both sysroots to a common sysroot (workaround ICU failing without one single sysroot)
        string(REPLACE "-clang" "" ANDROID_TOOLCHAIN_NAME ${ANDROID_TOOLCHAIN_NAME})
        file(COPY ${ANDROID_TOOLCHAIN_ROOT}/sysroot/usr/lib/${ANDROID_TOOLCHAIN_NAME}/${ANDROID_PLATFORM_LEVEL}/ DESTINATION ${CMAKE_CURRENT_BINARY_DIR}/sysroot/usr/lib/)
        file(COPY ${ANDROID_TOOLCHAIN_ROOT}/sysroot/usr/lib/${ANDROID_TOOLCHAIN_NAME}/ DESTINATION ${CMAKE_CURRENT_BINARY_DIR}/sysroot/usr/lib/ PATTERN *.*)
        file(COPY ${CMAKE_SYSROOT}/usr/include DESTINATION ${CMAKE_CURRENT_BINARY_DIR}/sysroot/usr/)

        set(CROSS_CFLAGS "")
        set(CROSS_CC "${CMAKE_C_COMPILER} ${CMAKE_C_COMPILE_OPTIONS_EXTERNAL_TOOLCHAIN}${CMAKE_C_COMPILER_EXTERNAL_TOOLCHAIN} --sysroot=${CMAKE_CURRENT_BINARY_DIR}/sysroot ${CMAKE_C_FLAGS} -target ${CMAKE_C_COMPILER_TARGET}")
        set(CROSS_CXX "${CMAKE_CXX_COMPILER} ${CMAKE_CXX_COMPILE_OPTIONS_EXTERNAL_TOOLCHAIN}${CMAKE_CXX_COMPILER_EXTERNAL_TOOLCHAIN} --sysroot=${CMAKE_CURRENT_BINARY_DIR}/sysroot ${CMAKE_CXX_FLAGS} ${CROSS_INCLUDES} -target ${CMAKE_CXX_COMPILER_TARGET}")
        set(CROSS_LDFLAGS "${CMAKE_MODULE_LINKER_FLAGS} ${CROSS_LIBS}")
    else()
        set(CROSS_CFLAGS "${CMAKE_C_FLAGS}")
        set(CROSS_CXXFLAGS "${CMAKE_CXX_FLAGS}")
        set(CROSS_CC "${CMAKE_C_COMPILER}")
        set(CROSS_CXX "${CMAKE_CXX_COMPILER}")
        set(CROSS_LDFLAGS "${CMAKE_MODULE_LINKER_FLAGS}")
    endif()

    set(CROSS_ENV_CMAKE ${CMAKE_COMMAND} -E env
            CC=${CROSS_CC}
            CXX=${CROSS_CXX}
            CFLAGS=${CROSS_CFLAGS}
            CXXFLAGS=${CROSS_CXXFLAGS}
            LDFLAGS=${CROSS_LDFLAGS}
    )
    
    # predict cross libraries
    GetICUByproducts(${CMAKE_CURRENT_BINARY_DIR}/icu_cross ICU_LIBRARIES ICU_LIBRARY_FILES ICU_INCLUDE_DIRS)

    ExternalProject_Add(
            icu_cross
            DEPENDS icu_host
            SOURCE_DIR ${CMAKE_CURRENT_BINARY_DIR}/icu
            BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/icu_cross-build
            CONFIGURE_COMMAND ${CROSS_ENV_CMAKE} sh <SOURCE_DIR>/source/configure --prefix=${CMAKE_CURRENT_BINARY_DIR}/icu_cross
            --libdir=${CMAKE_CURRENT_BINARY_DIR}/icu_cross/lib/ --host=${ICU_CROSS_ARCH} --with-cross-build=${CMAKE_CURRENT_BINARY_DIR}/icu_host-build ${ICU_CFG}
            BUILD_COMMAND ${CROSS_ENV_CMAKE} ${MAKE_PROGRAM} -j ${NUM_JOBS}
            BUILD_BYPRODUCTS ${ICU_LIBRARY_FILES}
            INSTALL_COMMAND ${CROSS_ENV_CMAKE} ${MAKE_PROGRAM} install
    )
    
    set(ICU_TARGET icu_cross)
    add_dependencies(icu icu_cross)
endif()
