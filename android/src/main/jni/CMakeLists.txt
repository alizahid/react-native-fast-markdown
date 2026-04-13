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

# --- React Native dependencies for Fabric shadow node ---
find_package(ReactAndroid REQUIRED CONFIG)
find_package(fbjni REQUIRED CONFIG)

find_library(log-lib log)

# --- Main shared library ---
add_library(react-native-markdown SHARED
  MarkdownParserJNI.cpp
  MarkdownViewShadowNode.cpp
)

# Our include dir comes first so our ComponentDescriptors.h
# overrides the codegen-generated one (injects custom shadow node).
target_include_directories(react-native-markdown BEFORE PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(react-native-markdown
  markdown_parser
  md4c
  fbjni::fbjni
  ReactAndroid::react_render_core
  ReactAndroid::react_render_componentregistry
  ReactAndroid::react_debug
  ReactAndroid::react_utils
  ReactAndroid::jsi
  ReactAndroid::yoga
  ${log-lib}
)

# Link the codegen-generated library if it exists (provides Props,
# EventEmitters, and the default ComponentDescriptors). The target
# is created by the React Native Gradle plugin after codegen runs.
if(TARGET react_codegen_MarkdownViewSpec)
  target_link_libraries(react-native-markdown react_codegen_MarkdownViewSpec)
endif()
