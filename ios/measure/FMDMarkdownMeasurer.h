#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Thread-safe measurement entry point used by the Fabric shadow node.
/// Shares the content cache with the mounted view, so measure work is
/// reused at mount time.
@interface FMDMarkdownMeasurer : NSObject

+ (CGFloat)measureMarkdown:(NSString *)markdown
                stylesJson:(NSString *)stylesJson
                  maxWidth:(CGFloat)maxWidth
                 fontScale:(CGFloat)fontScale;

@end

NS_ASSUME_NONNULL_END
