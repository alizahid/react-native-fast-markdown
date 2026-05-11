cmake_minimum_required(VERSION 3.22)
project(markdown_jni LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CPP_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../../../cpp)

add_library(markdown_jni SHARED
  MarkdownParserJni.cpp
  ${CPP_DIR}/md4c/md4c.c
  ${CPP_DIR}/parser/MarkdownParser.cpp
  ${CPP_DIR}/custom/CustomTagParser.cpp
)

target_include_directories(markdown_jni PRIVATE
  ${CPP_DIR}/md4c
  ${CPP_DIR}/parser
  ${CPP_DIR}/custom
)

find_library(log-lib log)
target_link_libraries(markdown_jni ${log-lib})
