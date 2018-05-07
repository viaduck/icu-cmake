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

# precompute future ICU library paths from build dir
function(GetICUByproducts ICU_PATH ICU_LIB_VAR ICU_INCLUDE_VAR)
    # include directory
    set(${ICU_INCLUDE_VAR} "${ICU_PATH}/include" PARENT_SCOPE)
    
    if (WIN32)
        # windows basenames and pre/suffixes
        set(ICU_BASE_NAMES dt in io tu uc)
        
        set(ICU_SHARED_PREFIX "lib")
        set(ICU_STATIC_PREFIX "libs")
        set(ICU_SHARED_SUFFIX ".dll.a")
        set(ICU_STATIC_SUFFIX ".a")
    else()
        # unix basenames and pre/suffixes
        set(ICU_BASE_NAMES data i18n io tu uc)
        
        set(ICU_SHARED_PREFIX ${CMAKE_SHARED_LIBRARY_PREFIX})
        set(ICU_STATIC_PREFIX ${CMAKE_STATIC_LIBRARY_PREFIX})
        set(ICU_SHARED_SUFFIX ${CMAKE_SHARED_LIBRARY_SUFFIX})
        set(ICU_STATIC_SUFFIX ${CMAKE_STATIC_LIBRARY_SUFFIX})
    endif()
    
    # add static and shared libs to the libraries variable
    foreach(ICU_BASE_NAME ${ICU_BASE_NAMES})
        set(ICU_SHARED_LIB "${ICU_PATH}/lib/${ICU_SHARED_PREFIX}icu${ICU_BASE_NAME}${ICU_SHARED_SUFFIX}")
        set(ICU_STATIC_LIB "${ICU_PATH}/lib/${ICU_STATIC_PREFIX}icu${ICU_BASE_NAME}${ICU_STATIC_SUFFIX}")
        
        list(APPEND ${ICU_LIB_VAR} ${ICU_SHARED_LIB} ${ICU_STATIC_LIB})
    endforeach()
    set(${ICU_LIB_VAR} ${${ICU_LIB_VAR}} PARENT_SCOPE)
endfunction()
