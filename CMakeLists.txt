cmake_minimum_required(VERSION 3.1)
project(ICU)

list(INSERT CMAKE_MODULE_PATH 0 "${CMAKE_CURRENT_SOURCE_DIR}/cmake-modules")

# Find or Build ICU
if (NOT ICU_CROSS)
    # try to find icu
    find_package(ICU REQUIRED data uc i18n io le lx)
endif()

if (ICU_CROSS)
    # try to compile icu
endif()

if (NOT ICU_FOUND)
    # could not find or compile icu
    MESSAGE(FATAL_ERROR "Could not find or compile ICU")
endif()

# declare interface target for ICU
add_library(icu INTERFACE)

target_link_libraries(icu INTERFACE ${ICU_LIBRARIES})
target_include_directories(icu INTERFACE ${ICU_INCLUDE_DIRS})