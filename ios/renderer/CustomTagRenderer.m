#import "CustomTagRenderer.h"
#import "ASTNodeWrapper.h"
#import "RenderContext.h"
#import "StyleAttributes.h"
#import "StyleConfig.h"

NSString *const MarkdownCustomTagKey = @"MarkdownCustomTag";
NSString *const MarkdownCustomTagPropsKey = @"MarkdownCustomTagProps";
NSString *const MarkdownSpoilerRangeKey = @"MarkdownSpoilerRange";

static NSString *const kMentionTag = @"Mention";
static NSString *const kSpoilerTag = @"Spoiler";

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
  [StyleAttributes applyStyle:style toAttrs:attrs];

  attrs[MarkdownCustomTagKey] = kMentionTag;
  attrs[MarkdownCustomTagPropsKey] = node.tagProps;

  NSString *user = node.tagProps[@"user"] ?: @"";
  NSString *displayText = [@"@" stringByAppendingString:user];

  [output appendAttributedString:
      [[NSAttributedString alloc] initWithString:displayText attributes:attrs]];
}

- (void)renderSpoiler:(ASTNodeWrapper *)node
                 into:(NSMutableAttributedString *)output
              context:(RenderContext *)context {
  NSMutableDictionary *attrs = [context.currentAttributes mutableCopy];

  // Mark the range as a spoiler — the overlay system will cover it.
  // We use a unique ID so multiple spoilers can be toggled independently.
  NSString *spoilerId = [[NSUUID UUID] UUIDString];
  attrs[MarkdownSpoilerRangeKey] = spoilerId;
  attrs[MarkdownCustomTagKey] = kSpoilerTag;

  [context pushAttributes:attrs];
  [context renderChildren:node into:output];
  [context popAttributes];
}

- (void)renderGenericTag:(ASTNodeWrapper *)node
                    into:(NSMutableAttributedString *)output
                 context:(RenderContext *)context {
  NSMutableDictionary *attrs = [context.currentAttributes mutableCopy];
  attrs[MarkdownCustomTagKey] = node.tagName;
  attrs[MarkdownCustomTagPropsKey] = node.tagProps;

  [context pushAttributes:attrs];
  [context renderChildren:node into:output];
  [context popAttributes];
}

@end
