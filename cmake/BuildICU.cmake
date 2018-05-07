# MIT License
#
# Copyright (c) 2018 The ViaDuck Project
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
string(REPLACE "." "_" ICU_URL_VERSION ${ICU_BUILD_VERSION})
#set(ICU_URL http://download.icu-project.org/files/icu4c/${ICU_BUILD_VERSION}/icu4c-${ICU_URL_VERSION}-src.tgz)
set(ICU_URL https://fossies.org/linux/misc/icu4c-${ICU_URL_VERSION}-src.tgz)

# download and unpack if needed
if (NOT EXISTS ${CMAKE_CURRENT_BINARY_DIR}/icu)
    file(DOWNLOAD ${ICU_URL} ${CMAKE_CURRENT_BINARY_DIR}/icu_src.tgz SHOW_PROGRESS)
    execute_process(COMMAND ${CMAKE_COMMAND} -E tar x ${CMAKE_CURRENT_BINARY_DIR}/icu_src.tgz WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
endif()

# if we are actually building for host, use cmake params for it
if (NOT ICU_CROSS_ARCH)
    set(HOST_CFLAGS "${CMAKE_C_FLAGS}")
    set(HOST_CXXFLAGS "${CMAKE_CXX_FLAGS}")
    set(HOST_CC "${CMAKE_C_COMPILER}")
    set(HOST_CXX "${CMAKE_CXX_COMPILER}")
    set(HOST_LDFLAGS "${CMAKE_MODULE_LINKER_FLAGS}")
    
    set(HOST_ENV_CMAKE ${CMAKE_COMMAND} -E env
            CC=${HOST_CC}
            CXX=${HOST_CXX}
            CFLAGS=${HOST_CFLAGS}
            CXXFLAGS=${HOST_CXXFLAGS}
            LDFLAGS=${HOST_LDFLAGS}
    )
    
    # predict host libraries
    GetICUByproducts(${CMAKE_CURRENT_BINARY_DIR}/icu_host ICU_LIBRARIES ICU_INCLUDE_DIRS)
endif()

ExternalProject_Add(
        icu_host
        SOURCE_DIR ${CMAKE_CURRENT_BINARY_DIR}/icu
        BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/icu_host-build
        CONFIGURE_COMMAND ${HOST_ENV_CMAKE} <SOURCE_DIR>/source/configure --enable-static --prefix=${CMAKE_CURRENT_BINARY_DIR}/icu_host --libdir=${CMAKE_CURRENT_BINARY_DIR}/icu_host/lib/
        BUILD_COMMAND ${HOST_ENV_CMAKE} ${MAKE_PROGRAM} -j ${NUM_JOBS}
        BUILD_BYPRODUCTS ${ICU_LIBRARIES}
        INSTALL_COMMAND ${HOST_ENV_CMAKE} ${MAKE_PROGRAM} install
)
add_dependencies(icu icu_host)

if (ICU_CROSS_ARCH)
    if (ANDROID)
        # copy over both sysroots to a common sysroot (workaround ICU failing without one single sysroot)
        file(COPY ${ANDROID_SYSTEM_LIBRARY_PATH}/usr DESTINATION ${CMAKE_CURRENT_BINARY_DIR}/sysroot/)
        file(COPY ${CMAKE_SYSROOT}/usr/include DESTINATION ${CMAKE_CURRENT_BINARY_DIR}/sysroot/usr/)

        # for c++ standard headers
        set(CROSS_INCLUDES "")
        foreach(INC ${CMAKE_CXX_STANDARD_INCLUDE_DIRECTORIES})
            set(CROSS_INCLUDES "${CROSS_INCLUDES} -I${INC}")
        endforeach()
        
        # for c++ standard libs
        set(CROSS_LIBS ${CMAKE_C_STANDARD_LIBRARIES_INIT})
        string(REPLACE "\" \"" ";" ANDROID_CXX_STANDARD_LIBRARIES ${ANDROID_CXX_STANDARD_LIBRARIES})
        string(REPLACE "\"" "" ANDROID_CXX_STANDARD_LIBRARIES ${ANDROID_CXX_STANDARD_LIBRARIES})
        foreach(LIB ${ANDROID_CXX_STANDARD_LIBRARIES})
            get_filename_component(LIB_PATH ${LIB} DIRECTORY)
            get_filename_component(LIB_NAME ${LIB} NAME_WE)
            # remove starting "lib"
            string(REGEX REPLACE "^lib" "" LIB_NAME ${LIB_NAME})
            
            set(CROSS_LIBS "${CROSS_LIBS} -L${LIB_PATH} -l${LIB_NAME}")
        endforeach()

        set(CROSS_CFLAGS "")
        # fix http://bugs.icu-project.org/trac/ticket/12854
        set(CROSS_CXXFLAGS "-DU_HAVE_XLOCALE_H=0")
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
    GetICUByproducts(${CMAKE_CURRENT_BINARY_DIR}/icu_cross ICU_LIBRARIES ICU_INCLUDE_DIRS)

    ExternalProject_Add(
            icu_cross
            DEPENDS icu_host
            SOURCE_DIR ${CMAKE_CURRENT_BINARY_DIR}/icu
            BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/icu_cross-build
            PATCH_COMMAND ${PATCH_PROGRAM} -p1 --forward -r - < ${CMAKE_CURRENT_SOURCE_DIR}/patches/0020-workaround-missing-locale.patch || true
            CONFIGURE_COMMAND ${CROSS_ENV_CMAKE} sh <SOURCE_DIR>/source/configure --enable-static --prefix=${CMAKE_CURRENT_BINARY_DIR}/icu_cross
            --libdir=${CMAKE_CURRENT_BINARY_DIR}/icu_cross/lib/ --host=${ICU_CROSS_ARCH} --with-cross-build=${CMAKE_CURRENT_BINARY_DIR}/icu_host-build
            BUILD_COMMAND ${CROSS_ENV_CMAKE} ${MAKE_PROGRAM} -j ${NUM_JOBS}
            BUILD_BYPRODUCTS ${ICU_LIBRARIES}
            INSTALL_COMMAND ${CROSS_ENV_CMAKE} ${MAKE_PROGRAM} install
    )
    
    add_dependencies(icu icu_cross)
endif()
