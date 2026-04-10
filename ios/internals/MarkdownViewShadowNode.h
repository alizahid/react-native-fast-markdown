#pragma once

#include "MarkdownViewState.h"
#include <react/renderer/components/MarkdownViewSpec/EventEmitters.h>
#include <react/renderer/components/MarkdownViewSpec/Props.h>
#include <react/renderer/components/view/ConcreteViewShadowNode.h>
#include <react/renderer/core/LayoutConstraints.h>
#include <react/renderer/core/LayoutContext.h>

namespace facebook::react {

// Defined by codegen in ShadowNodes.cpp — we just reference it.
extern const char MarkdownViewComponentName[];

class MarkdownViewShadowNode final : public ConcreteViewShadowNode<
                                         MarkdownViewComponentName,
                                         MarkdownViewProps,
                                         MarkdownViewEventEmitter,
                                         MarkdownViewState> {
public:
  using ConcreteViewShadowNode::ConcreteViewShadowNode;

  // Mark as leaf so Yoga calls measureContent()
  static ShadowNodeTraits BaseTraits() {
    auto traits = ConcreteViewShadowNode::BaseTraits();
    traits.set(ShadowNodeTraits::Trait::LeafYogaNode);
    return traits;
  }

  // Returns measured dimensions from state. Yoga calls this because
  // we're a LeafYogaNode.
  Size measureContent(
      const LayoutContext &layoutContext,
      const LayoutConstraints &layoutConstraints) const override;
};

} // namespace facebook::react
