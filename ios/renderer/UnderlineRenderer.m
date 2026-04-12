#import "UnderlineRenderer.h"
#import "ASTNodeWrapper.h"
#import "RenderContext.h"
#import "StyleAttributes.h"
#import "StyleConfig.h"

@implementation UnderlineRenderer

- (void)renderNode:(ASTNodeWrapper *)node
              into:(NSMutableAttributedString *)output
           context:(RenderContext *)context {
  MarkdownElementStyle *style = context.styleConfig.underline;
  NSMutableDictionary *attrs = [context.currentAttributes mutableCopy];

  // Apply font / color / background / kerning / line-height etc. in
  // one go. applyStyle will also touch the underline attrs if the
  // caller happens to set textDecorationLine, but we overwrite
  // them below to guarantee the underline is always drawn.
  [StyleAttributes applyStyle:style toAttrs:attrs];

  // Pattern — default to single, override via textDecorationStyle.
  NSUnderlineStyle pattern = NSUnderlineStyleSingle;
  if ([style.textDecorationStyle isEqualToString:@"double"]) {
    pattern = NSUnderlineStyleDouble;
  } else if ([style.textDecorationStyle isEqualToString:@"dotted"]) {
    pattern = NSUnderlineStyleSingle | NSUnderlinePatternDot;
  } else if ([style.textDecorationStyle isEqualToString:@"dashed"]) {
    pattern = NSUnderlineStyleSingle | NSUnderlinePatternDash;
  }
  attrs[NSUnderlineStyleAttributeName] = @(pattern);

  // Color — prefer explicit textDecorationColor, fall back to the
  // text color so callers who just set `color: 'red'` still get a
  // matching red underline.
  UIColor *underlineColor = style.textDecorationColor ?: style.color;
  if (underlineColor) {
    attrs[NSUnderlineColorAttributeName] = underlineColor;
  }

  [context pushAttributes:attrs];
  [context renderChildren:node into:output];
  [context popAttributes];
}

@end
