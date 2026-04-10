#pragma once

#include "MarkdownViewState.h"
#include <react/renderer/components/MarkdownViewSpec/EventEmitters.h>
#include <react/renderer/components/MarkdownViewSpec/Props.h>
#include <react/renderer/components/view/ConcreteViewShadowNode.h>
#include <react/renderer/core/LayoutConstraints.h>
#include <react/renderer/core/LayoutContext.h>

namespace facebook::react {

// Defined by codegen in ShadowNodes.cpp — we just reference it.
extern const char MarkdownViewComponentName[];

class MarkdownViewShadowNode final : public ConcreteViewShadowNode<
                                         MarkdownViewComponentName,
                                         MarkdownViewProps,
                                         MarkdownViewEventEmitter,
                                         MarkdownViewState> {
public:
  using ConcreteViewShadowNode::ConcreteViewShadowNode;

  Size measureContent(
      const LayoutContext &layoutContext,
      const LayoutConstraints &layoutConstraints) const override;

  void layout(LayoutContext layoutContext) override;

private:
  mutable int64_t localHeightCounter_{0};
};

} // namespace facebook::react
