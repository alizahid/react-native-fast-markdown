#include "MarkdownViewMeasurableShadowNode.h"

namespace facebook::react {

void MarkdownViewMeasurableShadowNode::setMeasurementsManager(
    const std::shared_ptr<MarkdownViewMeasurementsManager>&
        measurementsManager) {
  ensureUnsealed();
  measurementsManager_ = measurementsManager;
}

Size MarkdownViewMeasurableShadowNode::measureContent(
    const LayoutContext& /*layoutContext*/,
    const LayoutConstraints& layoutConstraints) const {
  return layoutConstraints.clamp(
      measurementsManager_->measure(
          getSurfaceId(), getConcreteProps(), layoutConstraints));
}

} // namespace facebook::react
