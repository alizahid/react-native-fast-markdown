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
/// MarkdownMentionOverlay scans the attributed string for this key
/// and installs a pressable overlay on each mention's glyph rects
/// that fires onMentionPress on tap.
extern NSString *const MarkdownMentionKey;

@interface CustomTagRenderer : NSObject <NodeRenderer>
@end
