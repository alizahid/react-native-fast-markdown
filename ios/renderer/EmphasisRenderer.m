#import "EmphasisRenderer.h"
#import "ASTNodeWrapper.h"
#import "RenderContext.h"
#import "StyleAttributes.h"
#import "StyleConfig.h"

@implementation EmphasisRenderer

- (void)renderNode:(ASTNodeWrapper *)node
              into:(NSMutableAttributedString *)output
           context:(RenderContext *)context {
  MarkdownElementStyle *style = context.styleConfig.emphasis;
  NSMutableDictionary *attrs = [context.currentAttributes mutableCopy];

  // Default: apply the italic trait to whatever font is currently in
  // effect. Skip when the caller supplied an explicit `fontStyle` or
  // `fontFamily` on the emphasis style — applyStyle below will build
  // the exact font they asked for.
  UIFont *currentFont = attrs[NSFontAttributeName];
  BOOL userOverridesFont = style.fontStyle != nil || style.fontFamily != nil;
  if (currentFont && !userOverridesFont) {
    UIFontDescriptor *descriptor = [currentFont.fontDescriptor
        fontDescriptorWithSymbolicTraits:currentFont.fontDescriptor.symbolicTraits |
                                         UIFontDescriptorTraitItalic];
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
