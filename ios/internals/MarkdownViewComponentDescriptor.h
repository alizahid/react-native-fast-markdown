#pragma once

#include <react/renderer/core/ConcreteComponentDescriptor.h>

#include "MarkdownViewShadowNode.h"

namespace facebook::react {

/// Component descriptor that wires our custom shadow node (with
/// measureContent) into Fabric instead of the codegen default.
class MarkdownViewComponentDescriptor final
    : public ConcreteComponentDescriptor<MarkdownViewShadowNode> {
 public:
  using ConcreteComponentDescriptor::ConcreteComponentDescriptor;
};

} // namespace facebook::react
