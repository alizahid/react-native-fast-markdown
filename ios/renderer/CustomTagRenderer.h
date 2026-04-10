#import "NodeRenderer.h"

// Attributed string keys for custom tag metadata
extern NSString *const MarkdownCustomTagKey;
extern NSString *const MarkdownCustomTagPropsKey;

// Attributed string key marking spoiler text ranges.
// Value is a unique spoiler ID (NSString) for independent toggling.
extern NSString *const MarkdownSpoilerRangeKey;

@interface CustomTagRenderer : NSObject <NodeRenderer>
@end
