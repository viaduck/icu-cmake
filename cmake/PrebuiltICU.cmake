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

# check out prebuilts for the current system

# includes
include(ExternalProject)
include(TargetArch)

# autodetect PREBUILT_BRANCH
target_architecture(ARCH)
if (WIN32)
    # prebuilts on windows use mingw-w64 for building
    set(ARCH_SYSTEM ${ARCH}-w64-mingw32)
elseif(UNIX AND NOT APPLE)
    set(ARCH_SYSTEM ${ARCH}-linux)
else()
    message(FATAL_ERROR "Prebuilts this system are not available (yet)!")
endif()
message(STATUS "Using ${ARCH_SYSTEM} prebuilts")
set(PREBUILT_BRANCH ${ARCH_SYSTEM} CACHE STRING "Branch in ICU-Prebuilts to checkout from")

# add icu prebuilt target
ExternalProject_Add(icu_pre
        GIT_REPOSITORY https://gl.viaduck.org/viaduck/icu-prebuilts.git
        GIT_TAG ${PREBUILT_BRANCH}

        UPDATE_COMMAND ""
        CONFIGURE_COMMAND ""
        BUILD_COMMAND ""
        INSTALL_COMMAND ""
        COMMAND ${CMAKE_COMMAND} -G ${CMAKE_GENERATOR} ${CMAKE_BINARY_DIR}
        TEST_COMMAND ""
)
add_dependencies(icu icu_pre)
set(ICU_ROOT_DIR ${CMAKE_CURRENT_BINARY_DIR}/icu_pre-prefix/src/icu_pre/${PREBUILT_BRANCH} CACHE INTERNAL "" FORCE)
