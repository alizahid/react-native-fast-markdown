#import "StrongRenderer.h"
#import "ASTNodeWrapper.h"
#import "RenderContext.h"
#import "StyleConfig.h"

@implementation StrongRenderer

- (void)renderNode:(ASTNodeWrapper *)node
              into:(NSMutableAttributedString *)output
           context:(RenderContext *)context {
  MarkdownElementStyle *style = context.styleConfig.strong;
  NSMutableDictionary *attrs = [context.currentAttributes mutableCopy];

  // Apply bold trait to current font
  UIFont *currentFont = attrs[NSFontAttributeName] ?: [UIFont systemFontOfSize:16];
  UIFontDescriptor *descriptor = [currentFont.fontDescriptor
      fontDescriptorWithSymbolicTraits:currentFont.fontDescriptor.symbolicTraits |
                                       UIFontDescriptorTraitBold];
  if (descriptor) {
    attrs[NSFontAttributeName] = [UIFont fontWithDescriptor:descriptor size:currentFont.pointSize];
  }

  if (style && style.color) {
    attrs[NSForegroundColorAttributeName] = style.color;
  }

  [context pushAttributes:attrs];
  [context renderChildren:node into:output];
  [context popAttributes];
}

@end
