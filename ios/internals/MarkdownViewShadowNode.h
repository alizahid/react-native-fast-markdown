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

  // Mark as leaf so Yoga calls measureContent() instead of
  // laying out children.
  static ShadowNodeTraits BaseTraits() {
    auto traits = ConcreteViewShadowNode::BaseTraits();
    traits.set(ShadowNodeTraits::Trait::LeafYogaNode);
    return traits;
  }

  Size measureContent(
      const LayoutContext &layoutContext,
      const LayoutConstraints &layoutConstraints) const override;

  // Called when the shadow node is cloned (e.g. due to state update).
  // Checks if state counter changed and marks Yoga dirty for re-measurement.
  void dirtyLayoutIfNeeded();

private:
  mutable int64_t localHeightCounter_{0};
};

} // namespace facebook::react
