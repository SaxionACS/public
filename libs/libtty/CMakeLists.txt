cmake_minimum_required(VERSION 3.22)
project(libtty)

set(target libtty)

add_executable(${target})

target_sources(${target}
        PRIVATE
        main.cpp)

target_compile_features(${target} PRIVATE cxx_std_20)
set_target_properties(${target} PROPERTIES CXX_EXTENSIONS OFF)

# Set options for gnu-like
target_compile_options(${target} PRIVATE
        # set warnings for all build types
        $<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-Wall -Wextra -Wpedantic -Werror -Wconversion -Wfloat-equal
        -Wformat-nonliteral -Wformat-security -Wformat-y2k -Wformat=2 -Wlogical-not-parentheses
        -Wmissing-declarations -Wmissing-field-initializers -Wmissing-format-attribute -Walloca -Wmissing-include-dirs -Wmissing-noreturn -Wpacked -Wpointer-arith -Wundef
        -Wredundant-decls -Wshadow -Wstack-protector -Wswitch-enum -Wwrite-strings>

        $<$<CXX_COMPILER_ID:GNU>:-Wlogical-op -Walloc-zero>

        # optimisation in Release
        $<$<AND:$<CXX_COMPILER_ID:GNU,Clang,AppleClang>,$<CONFIG:Release>>:-O3>

        # O3 optimisation Debug
        $<$<AND:$<CXX_COMPILER_ID:GNU,Clang,AppleClang>,$<CONFIG:Debug>>:-Og -g -fno-omit-frame-pointer>

        # static analyser for GNU in Debug
        $<$<AND:$<CXX_COMPILER_ID:GNU>,$<CONFIG:Debug>>:-fanalyzer>
        )

# Set options for MSVC
target_compile_options(${target} PRIVATE
        # set warnings for all build types
        $<$<CXX_COMPILER_ID:MSVC>:/Wall>
        # debug optimisation in Debug
        $<$<AND:$<CXX_COMPILER_ID:MSVC>,$<CONFIG:Release>>:/O2>
        # O3 optimisation in Release
        $<$<AND:$<CXX_COMPILER_ID:MSVC>,$<CONFIG:Debug>>:/RTC1 /Od /Zi>
        )

# ASAN things
option(USE_ASAN "Use address sanitizer if available" ON)

set(HAS_ASAN FALSE)

if (NOT CMAKE_CXX_COMPILER_ID MATCHES "MSVC")

    execute_process(COMMAND "${CMAKE_C_COMPILER}" -print-file-name=libasan.so
            OUTPUT_VARIABLE LIBASAN_PATH
            RESULT_VARIABLE ASAN_RESULT
            OUTPUT_STRIP_TRAILING_WHITESPACE)

    if (USE_ASAN AND (${ASAN_RESULT} EQUAL 0) AND (NOT ${LIBASAN_PATH} STREQUAL ""))
        message("libasan found @${LIBASAN_PATH}")
        message("Address Sanitizer enabled. To disable it set USE_ASAN to OFF.\n")
        set(HAS_ASAN TRUE)
    endif ()

else ()
    message("Address Sanitizer disabled for MSVC builds")

endif (NOT CMAKE_CXX_COMPILER_ID MATCHES "MSVC")

if (${USE_ASAN} AND ${HAS_ASAN})
    target_compile_options(${target} PRIVATE -fsanitize=address)
    target_link_options(${target} PRIVATE -fsanitize=address)
endif (${USE_ASAN} AND ${HAS_ASAN})

# automatic gitignore for build directories
if (NOT EXISTS ${PROJECT_BINARY_DIR}/.gitignore)
    file(WRITE ${PROJECT_BINARY_DIR}/.gitignore "*")
endif ()