// Override the codegen-generated ComponentDescriptors.h to use our
// custom MarkdownViewShadowNode (with measureContent) instead of
// the default ConcreteViewShadowNode.
#pragma once

#include <react/renderer/core/ConcreteComponentDescriptor.h>
#include <react/renderer/components/MarkdownViewSpec/EventEmitters.h>
#include <react/renderer/components/MarkdownViewSpec/Props.h>
#include <react/renderer/components/view/ConcreteViewShadowNode.h>
#include "MarkdownViewShadowNode.h"

// Include the generated descriptors for MarkdownEditorView which
// uses the default shadow node (no custom measurement needed).
// We only override MarkdownView's descriptor here.
namespace facebook::react {

class MarkdownViewComponentDescriptor final
    : public ConcreteComponentDescriptor<MarkdownViewShadowNode> {
 public:
  using ConcreteComponentDescriptor::ConcreteComponentDescriptor;
};

// MarkdownEditorView uses the default codegen shadow node — no
// measurement override needed. We must still provide its descriptor
// here since we're replacing the generated ComponentDescriptors.h.
extern const char MarkdownEditorViewComponentName[];

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
