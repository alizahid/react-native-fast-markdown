#pragma once

#include <react/renderer/components/MarkdownViewSpec/Props.h>
#include <react/renderer/components/MarkdownViewSpec/EventEmitters.h>
#include <react/renderer/core/ConcreteComponentDescriptor.h>
#include <react/renderer/core/LayoutContext.h>
#include <react/renderer/core/ShadowNode.h>
#include <react/renderer/components/view/ConcreteViewShadowNode.h>
#include "MarkdownViewState.h"

namespace facebook::react {

extern const char MarkdownViewComponentName[];

using MarkdownViewShadowNode = ConcreteViewShadowNode<
    MarkdownViewComponentName,
    MarkdownViewProps,
    MarkdownViewEventEmitter,
    MarkdownViewState>;

} // namespace facebook::react
