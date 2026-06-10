#pragma once

#include <react/renderer/components/MarkdownViewSpec/Props.h>
#include <react/renderer/core/LayoutConstraints.h>
#include <react/utils/ContextContainer.h>

namespace facebook::react {

/// Bridges shadow-thread measurement to the Java side. Mirrors RN
/// core's AndroidProgressBarMeasurementsManager: serializes the props
/// the measurer needs (markdown, styles, customTags, images) into a
/// ReadableNativeMap and JNI-calls FabricUIManager.measure, which
/// routes to MarkdownViewManager.measure → MarkdownMeasurer.
class MarkdownViewMeasurementsManager {
 public:
  MarkdownViewMeasurementsManager(
      const std::shared_ptr<const ContextContainer>& contextContainer)
      : contextContainer_(contextContainer) {}

  Size measure(
      SurfaceId surfaceId,
      const MarkdownViewProps& props,
      LayoutConstraints layoutConstraints) const;

 private:
  const std::shared_ptr<const ContextContainer> contextContainer_;
};

} // namespace facebook::react
