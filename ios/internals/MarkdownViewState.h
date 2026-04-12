#pragma once

#ifdef __cplusplus

namespace facebook::react {

/// State for MarkdownViewShadowNode. We don't actually read this
/// during measureContent — its only purpose is to give the native
/// component view a handle for forcing Yoga to re-run layout when
/// something external changes that the shadow tree can't see
/// (notably: a block image finishing its async download and
/// updating MarkdownImageSizeCache with its natural size).
///
/// Bumping `revision` via ConcreteState<MarkdownViewState>::
/// updateState triggers a new shadow-tree commit, which dirties
/// the node and makes Yoga call measureContent again. That call
/// re-reads MarkdownImageSizeCache for each block image in the
/// markdown and reserves the right space.
class MarkdownViewState final {
public:
  int64_t revision{0};
};

} // namespace facebook::react

#endif
