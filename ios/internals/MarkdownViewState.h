#pragma once

#ifdef __cplusplus

namespace facebook::react {

// Carries measured content height from the native view to the shadow node.
// When the view renders new content, it bumps the counter and updates
// the measured dimensions. The shadow node sees the counter change,
// marks the Yoga node dirty, and returns the measured height from
// measureContent(). No JS roundtrip needed.
class MarkdownViewState {
public:
  int64_t heightUpdateCounter{0};
  float measuredHeight{0};
  float measuredWidth{0};
};

} // namespace facebook::react

#endif
