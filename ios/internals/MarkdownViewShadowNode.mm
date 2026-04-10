#include "MarkdownViewShadowNode.h"

namespace facebook::react {

Size MarkdownViewShadowNode::measureContent(
    const LayoutContext & /*layoutContext*/,
    const LayoutConstraints & /*layoutConstraints*/) const {
  const auto &stateData = getStateData();
  return Size{stateData.measuredWidth, stateData.measuredHeight};
}

void MarkdownViewShadowNode::layout(LayoutContext layoutContext) {
  // Check if native view updated the state (bumped counter).
  // If so, mark Yoga node dirty to trigger re-measurement.
  const auto &stateData = getStateData();
  if (stateData.heightUpdateCounter != localHeightCounter_) {
    localHeightCounter_ = stateData.heightUpdateCounter;
    YogaLayoutableShadowNode::dirtyLayout();
  }

  ConcreteViewShadowNode::layout(layoutContext);
}

} // namespace facebook::react
