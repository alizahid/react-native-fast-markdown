#pragma once

#include <functional>
#include <mutex>
#include <string>

namespace fastmarkdown {

// Seam between the platform-agnostic shadow node and platform text layout.
// iOS installs a lambda over FMDMarkdownMeasurer; Android installs a JNI
// call into MarkdownMeasurer.kt. Runs on the Fabric layout thread.
class FastMarkdownMeasurer {
 public:
  using MeasureFunction = std::function<float(
      const std::string& markdown,
      const std::string& stylesJson,
      float maxWidth,
      float fontScale)>;

  static FastMarkdownMeasurer& shared();

  void install(MeasureFunction fn);

  // Returns the content height for the given constraints; 0 when no
  // platform measurer is installed yet.
  float measure(
      const std::string& markdown,
      const std::string& stylesJson,
      float maxWidth,
      float fontScale) const;

 private:
  mutable std::mutex mutex_;
  MeasureFunction fn_;
};

} // namespace fastmarkdown
