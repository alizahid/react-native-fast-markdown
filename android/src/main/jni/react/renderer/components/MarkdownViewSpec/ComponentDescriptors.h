// Override the codegen-generated ComponentDescriptors.h to inject
// our custom MarkdownViewShadowNode (with measureContent) instead
// of the default ConcreteViewShadowNode.
//
// This file lives at a path that shadows the codegen-generated one.
// The app's cmake (via autolinking) compiles the codegen C++ which
// includes <react/renderer/components/MarkdownViewSpec/ComponentDescriptors.h>.
// Because the library's jni/ dir is on the include path, this file
// gets found first.
#pragma once

#include <react/renderer/core/ConcreteComponentDescriptor.h>
#include <react/renderer/components/MarkdownViewSpec/EventEmitters.h>
#include <react/renderer/components/MarkdownViewSpec/Props.h>
#include <react/renderer/components/view/ConcreteViewShadowNode.h>

// Pull in our custom shadow node (header-only, inline measureContent).
// When running from the library source tree the header is four dirs up;
// when copied into the codegen output it sits next to this file.
#if __has_include("MarkdownViewShadowNode.h")
#include "MarkdownViewShadowNode.h"
#else
#include "../../../../MarkdownViewShadowNode.h"
#endif

namespace facebook::react {

// Symbol definitions (must appear in exactly one compilation unit).
inline const char MarkdownViewComponentName[] = "MarkdownView";
inline const char MarkdownEditorViewComponentName[] = "MarkdownEditorView";

// MarkdownView — uses our custom shadow node with Yoga measurement.
class MarkdownViewComponentDescriptor final
    : public ConcreteComponentDescriptor<MarkdownViewShadowNode> {
 public:
  using ConcreteComponentDescriptor::ConcreteComponentDescriptor;
};

// MarkdownEditorView — standard codegen shadow node (no custom measurement).
class MarkdownEditorViewShadowNode final
    : public ConcreteViewShadowNode<
          MarkdownEditorViewComponentName,
          MarkdownEditorViewProps,
          MarkdownEditorViewEventEmitter> {
 public:
  using ConcreteViewShadowNode::ConcreteViewShadowNode;
};

using MarkdownEditorViewComponentDescriptor =
    ConcreteComponentDescriptor<MarkdownEditorViewShadowNode>;

} // namespace facebook::react
