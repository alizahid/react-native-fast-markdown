#pragma once

#include <react/renderer/core/ConcreteComponentDescriptor.h>
#include "MarkdownViewShadowNode.h"

namespace facebook::react {

// Custom ComponentDescriptor that enables state for MarkdownView.
// This replaces the codegen-generated descriptor so we can use
// our MarkdownViewState for native-driven measurement.
using MarkdownViewComponentDescriptor =
    ConcreteComponentDescriptor<MarkdownViewShadowNode>;

} // namespace facebook::react
