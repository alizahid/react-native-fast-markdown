#pragma once

#include <react/renderer/components/FastMarkdownViewSpec/EventEmitters.h>
#include <react/renderer/components/FastMarkdownViewSpec/Props.h>
#include <react/renderer/components/view/ConcreteViewShadowNode.h>
#include <react/renderer/core/LayoutConstraints.h>
#include <react/renderer/core/LayoutContext.h>

#include "FastMarkdownState.h"

namespace facebook::react {

// Defined in the codegen-generated ShadowNodes.cpp.
extern const char FastMarkdownViewComponentName[];

// Custom shadow node: sizes the component to its markdown content via the
// platform measurer, replacing the codegen default (which cannot measure).
class FastMarkdownShadowNode final : public ConcreteViewShadowNode<
                                         FastMarkdownViewComponentName,
                                         FastMarkdownViewProps,
                                         FastMarkdownViewEventEmitter,
                                         FastMarkdownState> {
 public:
  FastMarkdownShadowNode(
      const ShadowNodeFragment& fragment,
      const ShadowNodeFamily::Shared& family,
      ShadowNodeTraits traits)
      : ConcreteViewShadowNode(fragment, family, traits) {}

  FastMarkdownShadowNode(
      const ShadowNode& sourceShadowNode,
      const ShadowNodeFragment& fragment)
      : ConcreteViewShadowNode(sourceShadowNode, fragment) {
    // State carries image sizes, which affect measureContent; Yoga must
    // re-measure when a new state arrives.
    if (fragment.state != nullptr) {
      dirtyLayout();
    }
  }

  static ShadowNodeTraits BaseTraits() {
    auto traits = ConcreteViewShadowNode::BaseTraits();
    traits.set(ShadowNodeTraits::Trait::LeafYogaNode);
    traits.set(ShadowNodeTraits::Trait::MeasurableYogaNode);
    return traits;
  }

  Size measureContent(
      const LayoutContext& layoutContext,
      const LayoutConstraints& layoutConstraints) const override;
};

} // namespace facebook::react
