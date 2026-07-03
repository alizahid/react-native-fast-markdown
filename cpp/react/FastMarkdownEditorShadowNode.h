#pragma once

#include <react/renderer/components/FastMarkdownViewSpec/EventEmitters.h>
#include <react/renderer/components/FastMarkdownViewSpec/Props.h>
#include <react/renderer/components/view/ConcreteViewShadowNode.h>
#include <react/renderer/core/LayoutConstraints.h>
#include <react/renderer/core/LayoutContext.h>

#include "FastMarkdownEditorState.h"

namespace facebook::react {

// Defined in the codegen-generated ShadowNodes.cpp.
extern const char FastMarkdownEditorComponentName[];

// Custom shadow node: the editor grows with its content. The platform view
// publishes its measured height into state after every edit; before the
// first publish (initial layout), the shared markdown measurer sizes the
// defaultValue so prefilled editors mount at the right height.
class FastMarkdownEditorShadowNode final : public ConcreteViewShadowNode<
                                               FastMarkdownEditorComponentName,
                                               FastMarkdownEditorProps,
                                               FastMarkdownEditorEventEmitter,
                                               FastMarkdownEditorState> {
 public:
  FastMarkdownEditorShadowNode(
      const ShadowNodeFragment& fragment,
      const ShadowNodeFamily::Shared& family,
      ShadowNodeTraits traits)
      : ConcreteViewShadowNode(fragment, family, traits) {}

  FastMarkdownEditorShadowNode(
      const ShadowNode& sourceShadowNode,
      const ShadowNodeFragment& fragment)
      : ConcreteViewShadowNode(sourceShadowNode, fragment) {
    // State carries the content height; Yoga must re-measure when a new
    // state arrives.
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
