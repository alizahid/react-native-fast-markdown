#import "StrongRenderer.h"
#import "ASTNodeWrapper.h"
#import "RenderContext.h"
#import "StyleAttributes.h"
#import "StyleConfig.h"

@implementation StrongRenderer

- (void)renderNode:(ASTNodeWrapper *)node
              into:(NSMutableAttributedString *)output
           context:(RenderContext *)context {
  MarkdownElementStyle *style = context.styleConfig.strong;
  NSMutableDictionary *attrs = [context.currentAttributes mutableCopy];

  // Default: apply the bold trait to whatever font is currently in
  // effect. Skip when the caller supplied an explicit `fontWeight`
  // or `fontFamily` on the strong style — applyStyle below will
  // build the exact font they asked for, so we shouldn't pollute
  // the base with a bold trait they'll immediately override.
  UIFont *currentFont = attrs[NSFontAttributeName];
  BOOL userOverridesFont = style.fontWeight != nil || style.fontFamily != nil;
  if (currentFont && !userOverridesFont) {
    UIFontDescriptor *descriptor = [currentFont.fontDescriptor
        fontDescriptorWithSymbolicTraits:currentFont.fontDescriptor.symbolicTraits |
                                         UIFontDescriptorTraitBold];
    if (descriptor) {
      attrs[NSFontAttributeName] =
          [UIFont fontWithDescriptor:descriptor size:currentFont.pointSize];
    }
  }

  [StyleAttributes applyStyle:style toAttrs:attrs];

  [context pushAttributes:attrs];
  [context renderChildren:node into:output];
  [context popAttributes];
}

@end
