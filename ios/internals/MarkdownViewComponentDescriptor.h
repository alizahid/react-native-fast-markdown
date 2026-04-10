#pragma once

#include "MarkdownViewShadowNode.h"
#include <react/renderer/core/ConcreteComponentDescriptor.h>

namespace facebook::react {

using MarkdownViewComponentDescriptor =
    ConcreteComponentDescriptor<MarkdownViewShadowNode>;

} // namespace facebook::react
