cmake_minimum_required(VERSION 3.13)
set(CMAKE_VERBOSE_MAKEFILE ON)

# Fabric component library for react-native-fast-markdown.
#
# This CMakeLists is referenced by react-native.config.js
# (`cmakeListsPath`) and built by the HOST APP's CMake via the
# autolinking-generated Android-autolinking.cmake — it is separate from
# the library's own externalNativeBuild (src/main/cpp), which builds the
# markdown parser JNI (libmarkdown_jni.so).
#
# It compiles the codegen output PLUS our custom Fabric files. The
# custom include dir is listed FIRST so our
# react/renderer/components/MarkdownViewSpec/ComponentDescriptors.h
# shadows the codegen-generated one — ours defines a MarkdownView
# descriptor whose shadow node measures markdown content on the shadow
# thread (the codegen default measures nothing, which collapses every
# <Markdown> to height 0). Same role ios/internals/MarkdownViewShadowNode
# plays on iOS.

set(LIB_LITERAL MarkdownViewSpec)
set(LIB_TARGET_NAME react_codegen_${LIB_LITERAL})

set(LIB_ANDROID_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../..)
set(LIB_ANDROID_GENERATED_JNI_DIR ${LIB_ANDROID_DIR}/build/generated/source/codegen/jni)
set(LIB_ANDROID_GENERATED_COMPONENTS_DIR ${LIB_ANDROID_GENERATED_JNI_DIR}/react/renderer/components/${LIB_LITERAL})
set(LIB_CUSTOM_DIR ${CMAKE_CURRENT_SOURCE_DIR}/fabric)

file(GLOB LIB_CUSTOM_SRCS CONFIGURE_DEPENDS
  ${LIB_CUSTOM_DIR}/react/renderer/components/${LIB_LITERAL}/*.cpp)
file(GLOB LIB_CODEGEN_SRCS CONFIGURE_DEPENDS
  ${LIB_ANDROID_GENERATED_JNI_DIR}/*.cpp
  ${LIB_ANDROID_GENERATED_COMPONENTS_DIR}/*.cpp)

# The codegen'd ComponentDescriptors.cpp registers the DEFAULT
# (non-measuring) MarkdownView descriptor. We exclude it and provide our
# own registration (ComponentDescriptorsRegistration.cpp) with the same
# exported symbol, registering the measuring descriptor instead.
list(REMOVE_ITEM LIB_CODEGEN_SRCS
  ${LIB_ANDROID_GENERATED_COMPONENTS_DIR}/ComponentDescriptors.cpp)

add_library(
  ${LIB_TARGET_NAME}
  SHARED
  ${LIB_CUSTOM_SRCS}
  ${LIB_CODEGEN_SRCS}
)

# Custom dir FIRST — its ComponentDescriptors.h must win over the
# codegen one for <react/renderer/components/MarkdownViewSpec/...>
# includes (both in autolinking.cpp and in our own sources).
target_include_directories(
  ${LIB_TARGET_NAME}
  PUBLIC
  ${LIB_CUSTOM_DIR}
  ${LIB_ANDROID_GENERATED_JNI_DIR}
)

target_link_libraries(
  ${LIB_TARGET_NAME}
  fbjni
  jsi
  reactnative
)

if(ReactAndroid_VERSION_MINOR GREATER_EQUAL 80)
  target_compile_reactnative_options(${LIB_TARGET_NAME} PUBLIC)
else()
  target_compile_options(
    ${LIB_TARGET_NAME}
    PRIVATE
    -fexceptions
    -frtti
    -std=c++20
    -Wall
  )
endif()
