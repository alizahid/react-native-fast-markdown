/**
 * Shadows the codegen-generated ComponentDescriptors.h (this directory
 * is first on the include path — see android/src/main/jni/CMakeLists.txt).
 *
 * The codegen default declares MarkdownViewComponentDescriptor as a
 * plain ConcreteComponentDescriptor whose shadow node never measures —
 * Yoga would lay every <Markdown> out at height 0. We swap in a
 * descriptor wired to MarkdownViewMeasurableShadowNode +
 * MarkdownViewMeasurementsManager (the AndroidSwitch pattern from RN
 * core) while keeping the exact same type names and registration symbol
 * the autolinking-generated autolinking.cpp expects.
 */

#pragma once

#include <react/renderer/components/MarkdownViewSpec/MarkdownViewMeasurableShadowNode.h>
#include <react/renderer/components/MarkdownViewSpec/MarkdownViewMeasurementsManager.h>
#include <react/renderer/components/MarkdownViewSpec/ShadowNodes.h>
#include <react/renderer/componentregistry/ComponentDescriptorProviderRegistry.h>
#include <react/renderer/core/ConcreteComponentDescriptor.h>

namespace facebook::react {

using MarkdownEditorViewComponentDescriptor =
    ConcreteComponentDescriptor<MarkdownEditorViewShadowNode>;

class MarkdownViewComponentDescriptor final
    : public ConcreteComponentDescriptor<MarkdownViewMeasurableShadowNode> {
 public:
  MarkdownViewComponentDescriptor(
      const ComponentDescriptorParameters& parameters)
      : ConcreteComponentDescriptor(parameters),
        measurementsManager_(std::make_shared<MarkdownViewMeasurementsManager>(
            contextContainer_)) {}

  void adopt(ShadowNode& shadowNode) const override {
    ConcreteComponentDescriptor::adopt(shadowNode);

    auto& markdownShadowNode =
        static_cast<MarkdownViewMeasurableShadowNode&>(shadowNode);
    markdownShadowNode.setMeasurementsManager(measurementsManager_);
  }

 private:
  const std::shared_ptr<MarkdownViewMeasurementsManager>
      measurementsManager_;
};

void MarkdownViewSpec_registerComponentDescriptorsFromCodegen(
    std::shared_ptr<const ComponentDescriptorProviderRegistry> registry);

} // namespace facebook::react
