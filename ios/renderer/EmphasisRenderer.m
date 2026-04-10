#import "EmphasisRenderer.h"
#import "ASTNodeWrapper.h"
#import "RenderContext.h"
#import "StyleConfig.h"

@implementation EmphasisRenderer

- (void)renderNode:(ASTNodeWrapper *)node
              into:(NSMutableAttributedString *)output
           context:(RenderContext *)context {
  NSMutableDictionary *attrs = [context.currentAttributes mutableCopy];

  UIFont *currentFont = attrs[NSFontAttributeName] ?: [UIFont systemFontOfSize:16];
  UIFontDescriptor *descriptor = [currentFont.fontDescriptor
      fontDescriptorWithSymbolicTraits:currentFont.fontDescriptor.symbolicTraits |
                                       UIFontDescriptorTraitItalic];
  if (descriptor) {
    attrs[NSFontAttributeName] = [UIFont fontWithDescriptor:descriptor size:currentFont.pointSize];
  }

  MarkdownElementStyle *style = context.styleConfig.emphasis;
  if (style && style.color) {
    attrs[NSForegroundColorAttributeName] = style.color;
  }

  [context pushAttributes:attrs];
  [context renderChildren:node into:output];
  [context popAttributes];
}

@end
