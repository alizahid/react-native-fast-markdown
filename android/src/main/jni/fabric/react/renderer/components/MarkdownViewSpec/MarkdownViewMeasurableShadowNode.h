#pragma once

#include <react/renderer/components/MarkdownViewSpec/MarkdownViewMeasurementsManager.h>
#include <react/renderer/components/MarkdownViewSpec/ShadowNodes.h>
#include <react/renderer/components/view/ConcreteViewShadowNode.h>

namespace facebook::react {

/// Android counterpart of ios/internals/MarkdownViewShadowNode: a leaf
/// Yoga node whose measureContent renders the markdown on the shadow
/// thread (via the Java MarkdownMeasurer, reached through the
/// measurements manager) so Yoga reserves the real content height on
/// the first layout pass.
///
/// Reuses the codegen'd MarkdownViewComponentName / Props /
/// EventEmitter / State (all pulled in via ShadowNodes.h) — only the
/// measurement behavior is custom, so prop parsing and event emission
/// stay identical to what codegen would have wired up.
class MarkdownViewMeasurableShadowNode final
    : public ConcreteViewShadowNode<
          MarkdownViewComponentName,
          MarkdownViewProps,
          MarkdownViewEventEmitter,
          MarkdownViewState> {
 public:
  using ConcreteViewShadowNode::ConcreteViewShadowNode;

  static ShadowNodeTraits BaseTraits() {
    auto traits = ConcreteViewShadowNode::BaseTraits();
    traits.set(ShadowNodeTraits::Trait::LeafYogaNode);
    traits.set(ShadowNodeTraits::Trait::MeasurableYogaNode);
    return traits;
  }

  void setMeasurementsManager(
      const std::shared_ptr<MarkdownViewMeasurementsManager>&
          measurementsManager);

  Size measureContent(
      const LayoutContext& layoutContext,
      const LayoutConstraints& layoutConstraints) const override;

 private:
  std::shared_ptr<MarkdownViewMeasurementsManager> measurementsManager_;
};

} // namespace facebook::react
