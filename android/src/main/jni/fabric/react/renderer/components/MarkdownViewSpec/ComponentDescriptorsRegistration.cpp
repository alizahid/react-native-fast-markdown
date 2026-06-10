/**
 * Replaces the codegen-generated ComponentDescriptors.cpp (excluded
 * from the build in CMakeLists.txt). Implements the same registration
 * symbol but registers the measuring MarkdownView descriptor defined in
 * our shadowing ComponentDescriptors.h.
 */

#include <react/renderer/components/MarkdownViewSpec/ComponentDescriptors.h>

namespace facebook::react {

void MarkdownViewSpec_registerComponentDescriptorsFromCodegen(
    std::shared_ptr<const ComponentDescriptorProviderRegistry> registry) {
  registry->add(
      concreteComponentDescriptorProvider<MarkdownViewComponentDescriptor>());
  registry->add(concreteComponentDescriptorProvider<
                MarkdownEditorViewComponentDescriptor>());
}

} // namespace facebook::react
