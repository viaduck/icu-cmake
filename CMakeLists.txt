cmake_minimum_required(VERSION 3.1)
project(ICU)

include(ProcessorCount)
include(ExternalProject)

list(INSERT CMAKE_MODULE_PATH 0 "${CMAKE_CURRENT_SOURCE_DIR}/cmake-modules")
ProcessorCount(NUM_JOBS)

find_program(MAKE_PROGRAM make)
# used to apply patches to ICU
find_program(PATCH_PROGRAM patch)
if (NOT PATCH_PROGRAM)
    message(FATAL_ERROR "Cannot find patch utility.")
endif()

# cache variables
set(BUILD_ICU OFF CACHE BOOL "Enable compilation of ICU")
set(ICU_BUILD_VERSION "61.1" CACHE STRING "ICU version to build")
set(ICU_CROSS_ARCH "" CACHE STRING "Target triplet for ICU cross compile")

if (BUILD_ICU AND ICU_ROOT_DIR)
    # try to find already build icu
    
    # workaround: prevent find_* from finding system files
    set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
    set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
    set(CMAKE_FIND_ROOT_PATH ${ICU_ROOT_DIR})
    find_package(ICU COMPONENTS data uc i18n io le lx QUIET)
    
    # check if we really found the requested version
    if (ICU_FOUND)
        foreach (LIB ${ICU_LIBRARIES})
            string(FIND ${LIB} ${ICU_ROOT_DIR} LIB_MATCH)
            if (NOT LIB_MATCH EQUAL 0)
                set(ICU_FOUND OFF)
            endif()
        endforeach()
    endif()
    
    if (ICU_FOUND)
        message(STATUS "Found compiled ICU. Remove to recompile.")
    else()
        message(STATUS "Could NOT find compiled ICU. Compiling.")
    endif()
elseif(NOT BUILD_ICU)
    # try to find icu
    find_package(ICU COMPONENTS data uc i18n io le lx REQUIRED)
endif()

# declare interface target for ICU
add_library(icu INTERFACE)

# Find or Build ICU
if (NOT ICU_FOUND AND BUILD_ICU)
    # try to compile icu
    string(REPLACE "." "_" ICU_URL_VERSION ${ICU_BUILD_VERSION})
    set(ICU_URL http://download.icu-project.org/files/icu4c/${ICU_BUILD_VERSION}/icu4c-${ICU_URL_VERSION}-src.tgz)

    if (NOT EXISTS ${CMAKE_CURRENT_BINARY_DIR}/icu)
        # download and unpack if needed
        file(DOWNLOAD ${ICU_URL} ${CMAKE_CURRENT_BINARY_DIR}/icu_src.tgz SHOW_PROGRESS)
        execute_process(COMMAND ${CMAKE_COMMAND} -E tar x icu_src.tgz)
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
        
          # force CMake-reload
        set(HOST_CMAKE_RELOAD ${CMAKE_COMMAND} -G ${CMAKE_GENERATOR} ${CMAKE_BINARY_DIR})
    else()
        set(HOST_CMAKE_RELOAD true)
    endif()
    
    ExternalProject_Add(
            icu_host
            SOURCE_DIR ${CMAKE_CURRENT_BINARY_DIR}/icu
            BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/icu_host-build
            CONFIGURE_COMMAND ${HOST_ENV_CMAKE} <SOURCE_DIR>/source/configure --enable-static --prefix=${CMAKE_CURRENT_BINARY_DIR}/icu_host
            BUILD_COMMAND ${HOST_ENV_CMAKE} ${MAKE_PROGRAM} -j ${NUM_JOBS}
            INSTALL_COMMAND ${HOST_ENV_CMAKE} ${MAKE_PROGRAM} install
            COMMAND ${HOST_CMAKE_RELOAD}
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

        ExternalProject_Add(
                icu_cross
                DEPENDS icu_host
                SOURCE_DIR ${CMAKE_CURRENT_BINARY_DIR}/icu
                BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/icu_cross-build
                PATCH_COMMAND ${PATCH_PROGRAM} -p1 --forward -r - < ${CMAKE_CURRENT_SOURCE_DIR}/patches/0020-workaround-missing-locale.patch || true
                CONFIGURE_COMMAND ${CROSS_ENV_CMAKE} sh <SOURCE_DIR>/source/configure --enable-static --prefix=${CMAKE_CURRENT_BINARY_DIR}/icu_cross
                --host=${ICU_CROSS_ARCH} --with-cross-build=${CMAKE_CURRENT_BINARY_DIR}/icu_host-build
                BUILD_COMMAND ${CROSS_ENV_CMAKE} ${MAKE_PROGRAM} -j ${NUM_JOBS}
                INSTALL_COMMAND ${CROSS_ENV_CMAKE} ${MAKE_PROGRAM} install
                COMMAND ${CMAKE_COMMAND} -G ${CMAKE_GENERATOR} ${CMAKE_BINARY_DIR}  # force CMake-reload
        )
        add_dependencies(icu icu_cross)

        set(ICU_ROOT_DIR ${CMAKE_CURRENT_BINARY_DIR}/icu_cross/ CACHE INTERNAL "" FORCE)
    else()
        set(ICU_ROOT_DIR ${CMAKE_CURRENT_BINARY_DIR}/icu_host/ CACHE INTERNAL "" FORCE)
    endif()

elseif(NOT ICU_FOUND AND NOT BUILD_ICU)

    # could not find or compile icu
    MESSAGE(FATAL_ERROR "Could not find or compile ICU")
endif()

target_link_libraries(icu INTERFACE ${ICU_LIBRARIES})
target_include_directories(icu INTERFACE ${ICU_INCLUDE_DIRS})
