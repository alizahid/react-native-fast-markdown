cmake_minimum_required(VERSION 3.13)
project(react-native-markdown)

set(CMAKE_CXX_STANDARD 17)

set(CPP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../cpp")

add_library(md4c STATIC
  ${CPP_DIR}/md4c/md4c.c
)

target_include_directories(md4c PUBLIC
  ${CPP_DIR}/md4c
)

add_library(markdown_parser STATIC
  ${CPP_DIR}/parser/MarkdownParser.cpp
  ${CPP_DIR}/custom/CustomTagParser.cpp
)

target_include_directories(markdown_parser PUBLIC
  ${CPP_DIR}/parser
  ${CPP_DIR}/custom
  ${CPP_DIR}/md4c
)

target_link_libraries(markdown_parser md4c)

add_library(react-native-markdown SHARED
  MarkdownParserJNI.cpp
)

find_library(log-lib log)

target_link_libraries(react-native-markdown
  markdown_parser
  md4c
  ${log-lib}
)
