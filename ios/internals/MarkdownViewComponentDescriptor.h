#pragma once

#include "MarkdownViewShadowNode.h"
#include <react/renderer/core/ConcreteComponentDescriptor.h>

namespace facebook::react {

// Custom descriptor that uses our MarkdownViewShadowNode (with state
// and measureContent) instead of the codegen-generated default.
class MarkdownViewComponentDescriptor
    : public ConcreteComponentDescriptor<MarkdownViewShadowNode> {
public:
  using ConcreteComponentDescriptor::ConcreteComponentDescriptor;
};

} // namespace facebook::react
