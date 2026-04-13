#pragma once

#include <react/renderer/core/ConcreteComponentDescriptor.h>
#include "MarkdownViewShadowNode.h"

namespace facebook::react {

using MarkdownViewComponentDescriptor =
    ConcreteComponentDescriptor<MarkdownViewShadowNode>;

} // namespace facebook::react
