#import "CustomTagRenderer.h"
#import "ASTNodeWrapper.h"
#import "RenderContext.h"
#import "StyleAttributes.h"
#import "StyleConfig.h"

NSString *const MarkdownCustomTagKey = @"MarkdownCustomTag";
NSString *const MarkdownCustomTagPropsKey = @"MarkdownCustomTagProps";
NSString *const MarkdownSpoilerRangeKey = @"MarkdownSpoilerRange";
NSString *const MarkdownMentionKey = @"MarkdownMention";
NSString *const MarkdownMentionTapURLString = @"mention://tap";

// Built-in mention tags.
static NSString *const kUserMentionTag = @"UserMention";
static NSString *const kChannelMentionTag = @"ChannelMention";
static NSString *const kCommandMentionTag = @"CommandMention";

static NSString *const kSpoilerTag = @"Spoiler";

@implementation CustomTagRenderer

- (void)renderNode:(ASTNodeWrapper *)node
              into:(NSMutableAttributedString *)output
           context:(RenderContext *)context {
  NSString *tag = node.tagName;

  if ([tag isEqualToString:kUserMentionTag]) {
    [self renderMentionNode:node
                       type:@"user"
                     prefix:@"@"
                      style:context.styleConfig.userMention
                       into:output
                    context:context];
  } else if ([tag isEqualToString:kChannelMentionTag]) {
    [self renderMentionNode:node
                       type:@"channel"
                     prefix:@"#"
                      style:context.styleConfig.channelMention
                       into:output
                    context:context];
  } else if ([tag isEqualToString:kCommandMentionTag]) {
    [self renderMentionNode:node
                       type:@"command"
                     prefix:@"/"
                      style:context.styleConfig.commandMention
                       into:output
                    context:context];
  } else if ([tag isEqualToString:kSpoilerTag]) {
    [self renderSpoiler:node into:output context:context];
  } else {
    [self renderGenericTag:node into:output context:context];
  }
}

#pragma mark - Mentions

- (void)renderMentionNode:(ASTNodeWrapper *)node
                     type:(NSString *)type
                   prefix:(NSString *)prefix
                    style:(MarkdownElementStyle *)style
                     into:(NSMutableAttributedString *)output
                  context:(RenderContext *)context {
  NSDictionary<NSString *, NSString *> *tagProps = node.tagProps;
  NSString *mentionId = tagProps[@"id"] ?: @"";
  NSString *mentionName = tagProps[@"name"] ?: @"";

  // Everything beyond id/name is an "extra prop" passed through to
  // onMentionPress.
  NSMutableDictionary<NSString *, NSString *> *extras =
      [NSMutableDictionary new];
  for (NSString *key in tagProps) {
    if ([key isEqualToString:@"id"] || [key isEqualToString:@"name"]) {
      continue;
    }
    extras[key] = tagProps[key] ?: @"";
  }

  // The data that onMentionPress will receive, stored directly on
  // the attributed string — no URL round-trip needed.
  NSDictionary *mentionData = @{
    @"type" : type,
    @"id" : mentionId,
    @"name" : mentionName,
    @"props" : [extras copy],
  };

  // Visual attrs come from the matching style key
  // (userMention/channelMention/commandMention).
  NSMutableDictionary *attrs = [context.currentAttributes mutableCopy];
  [StyleAttributes applyStyle:style toAttrs:attrs];

  attrs[MarkdownCustomTagKey] = node.tagName;
  attrs[MarkdownCustomTagPropsKey] = tagProps;
  attrs[MarkdownMentionKey] = mentionData;
  // NSLinkAttributeName is only used as a tap trigger — its value is
  // a fixed sentinel. MarkdownView.shouldInteractWithURL keys off the
  // `mention` scheme and reads the real data from MarkdownMentionKey
  // at the delegate-supplied character range.
  attrs[NSLinkAttributeName] =
      [NSURL URLWithString:MarkdownMentionTapURLString];

  // Display the prefix plus the name (or id as a fallback when name
  // is missing — typical for command mentions like `/help` that
  // don't carry a separate label).
  NSString *label = mentionName.length > 0 ? mentionName : mentionId;
  NSString *displayText = [prefix stringByAppendingString:label];

  [output appendAttributedString:
      [[NSAttributedString alloc] initWithString:displayText attributes:attrs]];
}

#pragma mark - Spoiler

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

#pragma mark - Generic fallback

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
