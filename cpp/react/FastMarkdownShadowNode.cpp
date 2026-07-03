#include "FastMarkdownShadowNode.h"

#include <algorithm>

#include "FastMarkdownMeasurer.h"

namespace facebook::react {

namespace {

void appendJsonEscaped(std::string& out, const std::string& value) {
  for (char c : value) {
    switch (c) {
      case '"': out += "\\\""; break;
      case '\\': out += "\\\\"; break;
      case '\n': out += "\\n"; break;
      case '\t': out += "\\t"; break;
      case '\r': out += "\\r"; break;
      default:
        if (static_cast<unsigned char>(c) < 0x20) {
          char buffer[8];
          snprintf(buffer, sizeof(buffer), "\\u%04x", c);
          out += buffer;
        } else {
          out += c;
        }
        break;
    }
  }
}

} // namespace

Size FastMarkdownShadowNode::measureContent(
    const LayoutContext& layoutContext,
    const LayoutConstraints& layoutConstraints) const {
  const auto& props = getConcreteProps();
  const auto& state = getStateData();

  // {"url":[w,h],...} — state sizes first, the images prop wins.
  std::string imagesJson = "{";
  bool first = true;
  auto appendEntry = [&](const std::string& url, double width, double height) {
    if (!first) {
      imagesJson += ',';
    }
    first = false;
    imagesJson += '"';
    appendJsonEscaped(imagesJson, url);
    imagesJson += "\":[";
    imagesJson += std::to_string(width);
    imagesJson += ',';
    imagesJson += std::to_string(height);
    imagesJson += ']';
  };
  for (const auto& [url, size] : state.imageSizes) {
    bool inProps = false;
    for (const auto& image : props.images) {
      if (image.url == url) {
        inProps = true;
        break;
      }
    }
    if (!inProps) {
      appendEntry(url, size.width, size.height);
    }
  }
  for (const auto& image : props.images) {
    appendEntry(image.url, image.width, image.height);
  }
  imagesJson += '}';

  const float maxWidth = layoutConstraints.maximumSize.width;
  // Font scaling is pinned to 1.0 until allowFontScaling lands; the host
  // views must use the same value so measured and rendered heights agree.
  (void)layoutContext;
  const float height = fastmarkdown::FastMarkdownMeasurer::shared().measure(
      props.markdown, props.stylesJson, imagesJson, maxWidth, 1.0f);

  Size size;
  size.width = maxWidth;
  size.height = std::clamp(
      static_cast<Float>(height),
      layoutConstraints.minimumSize.height,
      layoutConstraints.maximumSize.height);
  return size;
}

} // namespace facebook::react
