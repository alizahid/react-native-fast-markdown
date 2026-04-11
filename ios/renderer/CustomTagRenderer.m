#import "CustomTagRenderer.h"
#import "ASTNodeWrapper.h"
#import "RenderContext.h"
#import "StyleAttributes.h"
#import "StyleConfig.h"

NSString *const MarkdownCustomTagKey = @"MarkdownCustomTag";
NSString *const MarkdownCustomTagPropsKey = @"MarkdownCustomTagProps";
NSString *const MarkdownSpoilerRangeKey = @"MarkdownSpoilerRange";

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

  // Build the tap URL. Host = type, path = /id, query items carry
  // name + any extra props. textView:shouldInteractWithURL: routes
  // taps on this scheme to the onMentionPress event.
  NSURL *tapURL = [self mentionURLForType:type
                                       id:mentionId
                                     name:mentionName
                                tagProps:tagProps];

  // Visual attrs (font/color/bg from userMention/channelMention/
  // commandMention style).
  NSMutableDictionary *attrs = [context.currentAttributes mutableCopy];
  [StyleAttributes applyStyle:style toAttrs:attrs];

  attrs[MarkdownCustomTagKey] = node.tagName;
  attrs[MarkdownCustomTagPropsKey] = tagProps;
  if (tapURL) {
    attrs[NSLinkAttributeName] = tapURL;
  }

  // Display the prefix plus the name (or id as a fallback when name
  // is missing — typical for command mentions like `/help` that
  // don't carry a separate label).
  NSString *label = mentionName.length > 0 ? mentionName : mentionId;
  NSString *displayText = [prefix stringByAppendingString:label];

  [output appendAttributedString:
      [[NSAttributedString alloc] initWithString:displayText attributes:attrs]];
}

- (NSURL *)mentionURLForType:(NSString *)type
                          id:(NSString *)mentionId
                        name:(NSString *)name
                    tagProps:(NSDictionary<NSString *, NSString *> *)tagProps {
  NSURLComponents *components = [[NSURLComponents alloc] init];
  components.scheme = @"mention";
  components.host = type;
  components.path =
      [@"/" stringByAppendingString:mentionId ?: @""];

  NSMutableArray<NSURLQueryItem *> *items = [NSMutableArray new];
  if (name.length > 0) {
    [items addObject:[NSURLQueryItem queryItemWithName:@"name" value:name]];
  }
  for (NSString *key in tagProps) {
    if ([key isEqualToString:@"id"] || [key isEqualToString:@"name"]) {
      continue;
    }
    [items addObject:[NSURLQueryItem queryItemWithName:key
                                                 value:tagProps[key] ?: @""]];
  }
  if (items.count > 0) components.queryItems = items;

  return components.URL;
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
