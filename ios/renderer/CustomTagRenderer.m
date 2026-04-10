#import "CustomTagRenderer.h"
#import "ASTNodeWrapper.h"
#import "RenderContext.h"
#import "StyleConfig.h"

static NSString *const kMentionTag = @"Mention";
static NSString *const kSpoilerTag = @"Spoiler";
static NSString *const kCustomTagAttributeKey = @"MarkdownCustomTag";
static NSString *const kCustomTagPropsKey = @"MarkdownCustomTagProps";

@implementation CustomTagRenderer

- (void)renderNode:(ASTNodeWrapper *)node
              into:(NSMutableAttributedString *)output
           context:(RenderContext *)context {
  NSString *tag = node.tagName;

  if ([tag isEqualToString:kMentionTag]) {
    [self renderMention:node into:output context:context];
  } else if ([tag isEqualToString:kSpoilerTag]) {
    [self renderSpoiler:node into:output context:context];
  } else {
    [self renderGenericTag:node into:output context:context];
  }
}

- (void)renderMention:(ASTNodeWrapper *)node
                 into:(NSMutableAttributedString *)output
              context:(RenderContext *)context {
  MarkdownElementStyle *style = context.styleConfig.mention;
  NSMutableDictionary *attrs = [context.currentAttributes mutableCopy];

  NSString *user = node.tagProps[@"user"] ?: @"";
  NSString *prefix = style.prefix ?: @"@";
  NSString *displayText = [prefix stringByAppendingString:user];

  if (style) {
    UIFont *font = [style resolvedFont];
    if (font) attrs[NSFontAttributeName] = font;
    if (style.color) attrs[NSForegroundColorAttributeName] = style.color;
  } else {
    attrs[NSForegroundColorAttributeName] = [UIColor systemBlueColor];
  }

  // Store tag info for tap handling
  attrs[kCustomTagAttributeKey] = kMentionTag;
  attrs[kCustomTagPropsKey] = node.tagProps;

  [output appendAttributedString:
      [[NSAttributedString alloc] initWithString:displayText attributes:attrs]];
}

- (void)renderSpoiler:(ASTNodeWrapper *)node
                 into:(NSMutableAttributedString *)output
              context:(RenderContext *)context {
  MarkdownElementStyle *style = context.styleConfig.spoiler;
  NSMutableDictionary *attrs = [context.currentAttributes mutableCopy];

  UIColor *overlayColor = style.overlayColor ?: [UIColor labelColor];

  // Render spoiler as hidden text (background = foreground color)
  attrs[NSForegroundColorAttributeName] = overlayColor;
  attrs[NSBackgroundColorAttributeName] = overlayColor;
  attrs[kCustomTagAttributeKey] = kSpoilerTag;
  attrs[kCustomTagPropsKey] = node.tagProps;

  [context pushAttributes:attrs];
  [context renderChildren:node into:output];
  [context popAttributes];
}

- (void)renderGenericTag:(ASTNodeWrapper *)node
                    into:(NSMutableAttributedString *)output
                 context:(RenderContext *)context {
  NSMutableDictionary *attrs = [context.currentAttributes mutableCopy];
  attrs[kCustomTagAttributeKey] = node.tagName;
  attrs[kCustomTagPropsKey] = node.tagProps;

  [context pushAttributes:attrs];
  [context renderChildren:node into:output];
  [context popAttributes];
}

@end
