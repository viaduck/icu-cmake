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

cmake_minimum_required(VERSION 3.2)
project(icu-cmake)

# cache variables
set(BUILD_ICU OFF CACHE BOOL "Enable compilation of ICU")
set(ICU_BUILD_VERSION OFF CACHE STRING "ICU version to build")
set(ICU_STATIC OFF CACHE BOOL "Use static instead of shared ICU (does not work for system)")
set(ICU_CROSS_ARCH OFF CACHE STRING "Target triplet for ICU cross compile")
set(SYSTEM_ICU OFF CACHE BOOL "Use system-provided icu libraries (instead of prebuilts or building")

# allow including our modules
list(INSERT CMAKE_MODULE_PATH 0 "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
list(INSERT CMAKE_MODULE_PATH 0 "${CMAKE_CURRENT_SOURCE_DIR}/cmake-modules")

# declare interface target for ICU
add_library(icu INTERFACE)

if (SYSTEM_ICU)
    # try to find icu
    find_package(ICU COMPONENTS data uc i18n io le lx REQUIRED)
else()
    # build own or or use prebuilts
    
    # set up target
    if (BUILD_ICU)
        include(BuildICU)
    else()
        include(PrebuiltICU)
    endif()

    if (NOT ICU_STATIC)
        include(GNUInstallDirs)
        install(FILES ${ICU_LIBRARIES} DESTINATION ${CMAKE_INSTALL_LIBDIR})
    endif()
endif()

# link system, cross or host libraries to interface target
target_link_libraries(icu INTERFACE ${ICU_LIBRARIES})
target_include_directories(icu INTERFACE ${ICU_INCLUDE_DIRS})
