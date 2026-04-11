#import "NodeRenderer.h"

// Attributed string keys for custom tag metadata
extern NSString *const MarkdownCustomTagKey;
extern NSString *const MarkdownCustomTagPropsKey;

// Attributed string key marking spoiler text ranges.
// Value is a unique spoiler ID (NSString) for independent toggling.
extern NSString *const MarkdownSpoilerRangeKey;

/// Attributed string key marking mention ranges. Value is an
/// NSDictionary with:
///   @"type"  -> NSString ("user" | "channel" | "command")
///   @"id"    -> NSString
///   @"name"  -> NSString (may be empty)
///   @"props" -> NSDictionary<NSString *, NSString *> (extra attrs)
/// MarkdownView reads this at the delegate-supplied character range
/// when UITextView fires a link-tap, and routes it to onMentionPress.
extern NSString *const MarkdownMentionKey;

/// Sentinel URL used as the NSLinkAttributeName for mention ranges.
/// Only its scheme ("mention") is inspected — the real data lives in
/// the MarkdownMentionKey attribute on the same range.
extern NSString *const MarkdownMentionTapURLString;

@interface CustomTagRenderer : NSObject <NodeRenderer>
@end
