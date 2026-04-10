#include "MarkdownViewShadowNode.h"

namespace facebook::react {

Size MarkdownViewShadowNode::measureContent(
    const LayoutContext & /*layoutContext*/,
    const LayoutConstraints & /*layoutConstraints*/) const {
  const auto &stateData = getStateData();
  return Size{stateData.measuredWidth, stateData.measuredHeight};
}

} // namespace facebook::react
