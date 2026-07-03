#include "FastMarkdownEditorShadowNode.h"

#include <algorithm>

#include "FastMarkdownMeasurer.h"

namespace facebook::react {

Size FastMarkdownEditorShadowNode::measureContent(
    const LayoutContext& layoutContext,
    const LayoutConstraints& layoutConstraints) const {
  const auto& props = getConcreteProps();
  const auto& state = getStateData();

  const Float maxWidth = layoutConstraints.maximumSize.width;

  Float height = static_cast<Float>(state.height);
  if (height <= 0) {
    // Initial layout: size the defaultValue (or one empty line) with the
    // shared measurer so the editor mounts at its real height.
    const std::string& markdown =
        props.defaultValue.empty() ? " " : props.defaultValue;
    height = static_cast<Float>(fastmarkdown::FastMarkdownMeasurer::shared().measure(
        markdown,
        props.stylesJson,
        "{}",
        static_cast<float>(maxWidth),
        1.0f));
  }

  height = std::clamp(
      height,
      layoutConstraints.minimumSize.height,
      layoutConstraints.maximumSize.height);

  return Size{maxWidth, height};
}

} // namespace facebook::react
