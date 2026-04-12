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

/// When set (to @YES) alongside MarkdownSpoilerRangeKey on a spoiler
/// range, signals that the spoiler is block-level — i.e. the entire
/// top-level segment is the spoiler, not an inline span inside a
/// paragraph. MarkdownSpoilerOverlay uses this to render the
/// overlay as one solid rectangle instead of a staircase polygon
/// that follows the text contour.
extern NSString *const MarkdownSpoilerIsBlockKey;

@interface CustomTagRenderer : NSObject <NodeRenderer>
@end
