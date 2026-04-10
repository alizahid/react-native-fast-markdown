#pragma once

#ifdef __cplusplus

namespace facebook::react {

class MarkdownViewState {
public:
  // Counter bumped each time the view renders new content.
  // The shadow node uses this to know it needs to re-measure.
  int64_t heightUpdateCounter{0};

  // The measured content height from the last native render.
  float measuredHeight{0};

  // The measured content width.
  float measuredWidth{0};
};

} // namespace facebook::react

#endif
