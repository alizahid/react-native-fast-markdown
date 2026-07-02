#include "FastMarkdownMeasurer.h"

namespace fastmarkdown {

FastMarkdownMeasurer& FastMarkdownMeasurer::shared() {
  static FastMarkdownMeasurer instance;
  return instance;
}

void FastMarkdownMeasurer::install(MeasureFunction fn) {
  std::lock_guard<std::mutex> lock(mutex_);
  fn_ = std::move(fn);
}

float FastMarkdownMeasurer::measure(
    const std::string& markdown,
    const std::string& stylesJson,
    float maxWidth,
    float fontScale) const {
  MeasureFunction fn;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    fn = fn_;
  }
  if (!fn) {
    return 0.0f;
  }
  return fn(markdown, stylesJson, maxWidth, fontScale);
}

} // namespace fastmarkdown
