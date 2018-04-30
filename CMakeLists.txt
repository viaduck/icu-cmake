cmake_minimum_required(VERSION 3.1)
project(ICU)

include(ProcessorCount)
include(ExternalProject)

list(INSERT CMAKE_MODULE_PATH 0 "${CMAKE_CURRENT_SOURCE_DIR}/cmake-modules")
ProcessorCount(NUM_JOBS)

# used to apply various patches to ICU
find_program(PATCH_PROGRAM patch)
if (NOT PATCH_PROGRAM)
    message(FATAL_ERROR "Cannot find patch utility. This is only required for Android cross-compilation but due to script complexity "
            "the requirement is always enforced")
endif()

# used to make
find_program(MAKE_PROGRAM make)

set(BUILD_ICU ON)
#set(ICU_CROSS_ARCH x86_64-w64-mingw32)
set(ICU_CROSS_ARCH aarch64-linux-android)

if (NOT BUILD_ICU OR BUILD_ICU AND ICU_ROOT_DIR)
    # try to find icu
    find_package(ICU COMPONENTS data uc i18n io le lx)
endif()

# Find or Build ICU
if (NOT ICU_FOUND AND BUILD_ICU)
    # try to compile icu
    set(ICU_LIB_VERSION "61.1")
    set(ICU_URL_VERSION "61_1")
    set(ICU_URL http://download.icu-project.org/files/icu4c/${ICU_LIB_VERSION}/icu4c-${ICU_URL_VERSION}-src.tgz)


    if (NOT EXISTS ${CMAKE_CURRENT_BINARY_DIR}/icu)
        # download and unpack if needed
        file(DOWNLOAD ${ICU_URL} ${CMAKE_CURRENT_BINARY_DIR}/icu_src.tgz SHOW_PROGRESS)
        execute_process(COMMAND ${CMAKE_COMMAND} -E tar x icu_src.tgz)
    endif()

    ExternalProject_Add(
            icu_host
            SOURCE_DIR ${CMAKE_CURRENT_BINARY_DIR}/icu
            BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/icu_host-build
            CONFIGURE_COMMAND <SOURCE_DIR>/source/configure --enable-static --prefix=${CMAKE_CURRENT_BINARY_DIR}/icu_host
            BUILD_COMMAND ${MAKE_PROGRAM} -j ${NUM_JOBS}
    )

    if (ICU_CROSS_ARCH)
        # cross cflags
        if (ANDROID)
            # copy over both sysroots to a common sysroot (workaround OpenSSL failing without one single sysroot)
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
                set(CROSS_LIBS "${CROSS_LIBS} -l:${LIB}")
            endforeach()

            set(CROSS_CFLAGS "${CMAKE_C_FLAGS} -target ${CMAKE_C_COMPILER_TARGET}")
            set(CROSS_CXXFLAGS "${CMAKE_CXX_FLAGS} ${CROSS_INCLUDES} -target ${CMAKE_CXX_COMPILER_TARGET}")
            set(CROSS_CC "${CMAKE_C_COMPILER} ${CMAKE_C_COMPILE_OPTIONS_EXTERNAL_TOOLCHAIN}${CMAKE_C_COMPILER_EXTERNAL_TOOLCHAIN} --sysroot=${CMAKE_CURRENT_BINARY_DIR}/sysroot")
            set(CROSS_CXX "${CMAKE_CXX_COMPILER} ${CMAKE_CXX_COMPILE_OPTIONS_EXTERNAL_TOOLCHAIN}${CMAKE_CXX_COMPILER_EXTERNAL_TOOLCHAIN} --sysroot=${CMAKE_CURRENT_BINARY_DIR}/sysroot")
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
        )

        set(ICU_ROOT_DIR ${CMAKE_CURRENT_BINARY_DIR}/icu_cross CACHE INTERNAL "" FORCE)
    else()
        set(ICU_ROOT_DIR ${CMAKE_CURRENT_BINARY_DIR}/icu_host CACHE INTERNAL "" FORCE)
    endif()

elseif(NOT ICU_FOUND AND NOT BUILD_ICU)

    # could not find or compile icu
    MESSAGE(FATAL_ERROR "Could not find or compile ICU")
endif()

# declare interface target for ICU
add_library(icu INTERFACE)
add_dependencies(icu icu_host)

target_link_libraries(icu INTERFACE ${ICU_LIBRARIES})
target_include_directories(icu INTERFACE ${ICU_INCLUDE_DIRS})
