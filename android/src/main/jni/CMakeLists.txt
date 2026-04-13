cmake_minimum_required(VERSION 3.13)
project(react-native-markdown)

set(CMAKE_CXX_STANDARD 17)

set(CPP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../cpp")

# --- md4c static library ---
add_library(md4c STATIC
  ${CPP_DIR}/md4c/md4c.c
)
target_include_directories(md4c PUBLIC
  ${CPP_DIR}/md4c
)

# --- Markdown parser static library ---
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

# --- Main shared library (JNI parser bridge only) ---
# The Fabric shadow node (MarkdownViewShadowNode) is header-only
# and gets compiled by the app's cmake via the codegen include of
# our ComponentDescriptors.h override.
find_library(log-lib log)

add_library(react-native-markdown SHARED
  MarkdownParserJNI.cpp
)

target_link_libraries(react-native-markdown
  markdown_parser
  md4c
  ${log-lib}
)

# Make our jni/ directory available on the include path so that
# the codegen target finds our custom ComponentDescriptors.h
# (with custom shadow node) alongside the generated one.
# This is an INTERFACE property — it propagates to any target that
# links against react-native-markdown (including the codegen target
# when the autolinking cmake wires them together).
target_include_directories(react-native-markdown
  INTERFACE ${CMAKE_CURRENT_SOURCE_DIR}
)
