#pragma once

#include "MarkdownViewShadowNode.h"
#include <react/renderer/core/ConcreteComponentDescriptor.h>

namespace facebook::react {

class MarkdownViewComponentDescriptor
    : public ConcreteComponentDescriptor<MarkdownViewShadowNode> {
public:
  using ConcreteComponentDescriptor::ConcreteComponentDescriptor;

  void adopt(const ShadowNode::Unshared &shadowNode) const override {
    auto &node = static_cast<MarkdownViewShadowNode &>(*shadowNode);
    node.dirtyLayoutIfNeeded();
    ConcreteComponentDescriptor::adopt(shadowNode);
  }
};

} // namespace facebook::react
