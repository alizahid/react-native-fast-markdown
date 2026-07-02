#include "FastMarkdownShadowNode.h"

#include <algorithm>

#include "FastMarkdownMeasurer.h"

namespace facebook::react {

Size FastMarkdownShadowNode::measureContent(
    const LayoutContext& layoutContext,
    const LayoutConstraints& layoutConstraints) const {
  const auto& props = getConcreteProps();

  const float maxWidth = layoutConstraints.maximumSize.width;
  // Font scaling is pinned to 1.0 until allowFontScaling lands; the host
  // views must use the same value so measured and rendered heights agree.
  (void)layoutContext;
  const float height = fastmarkdown::FastMarkdownMeasurer::shared().measure(
      props.markdown, props.stylesJson, maxWidth, 1.0f);

  Size size;
  size.width = maxWidth;
  size.height = std::clamp(
      static_cast<Float>(height),
      layoutConstraints.minimumSize.height,
      layoutConstraints.maximumSize.height);
  return size;
}

} // namespace facebook::react
