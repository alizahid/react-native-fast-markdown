#pragma once

#ifdef __cplusplus

namespace facebook::react {

class MarkdownViewState {
public:
  int64_t heightUpdateCounter{0};
  float measuredHeight{0};
  float measuredWidth{0};

  bool operator==(const MarkdownViewState &other) const {
    return heightUpdateCounter == other.heightUpdateCounter;
  }

  bool operator!=(const MarkdownViewState &other) const {
    return !(*this == other);
  }
};

} // namespace facebook::react

#endif
