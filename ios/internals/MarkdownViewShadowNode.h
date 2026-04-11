#pragma once

#include <react/renderer/components/MarkdownViewSpec/EventEmitters.h>
#include <react/renderer/components/MarkdownViewSpec/Props.h>
#include <react/renderer/components/view/ConcreteViewShadowNode.h>

namespace facebook::react {

extern const char MarkdownViewComponentName[];

/// Custom shadow node that measures markdown content on the shadow
/// tree so Yoga lays the view out with the correct size on the first
/// pass — no layout shift, no JS round trip.
class MarkdownViewShadowNode final
    : public ConcreteViewShadowNode<
          MarkdownViewComponentName,
          MarkdownViewProps,
          MarkdownViewEventEmitter> {
 public:
  using ConcreteViewShadowNode::ConcreteViewShadowNode;

  static ShadowNodeTraits BaseTraits() {
    auto traits = ConcreteViewShadowNode::BaseTraits();
    traits.set(ShadowNodeTraits::Trait::LeafYogaNode);
    traits.set(ShadowNodeTraits::Trait::MeasurableYogaNode);
    return traits;
  }

  Size measureContent(
      const LayoutContext &layoutContext,
      const LayoutConstraints &layoutConstraints) const override;
};

} // namespace facebook::react
