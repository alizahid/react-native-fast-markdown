#include "MarkdownViewShadowNode.h"

namespace facebook::react {

Size MarkdownViewShadowNode::measureContent(
    const LayoutContext & /*layoutContext*/,
    const LayoutConstraints & /*layoutConstraints*/) const {
  const auto &stateData = getStateData();
  return Size{stateData.measuredWidth, stateData.measuredHeight};
}

void MarkdownViewShadowNode::dirtyLayoutIfNeeded() {
  const auto &stateData = getStateData();
  if (stateData.heightUpdateCounter != localHeightCounter_) {
    localHeightCounter_ = stateData.heightUpdateCounter;
    dirtyLayout();
  }
}

} // namespace facebook::react
