#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Callbacks from block views up to the host component view.
@protocol FMDMarkdownHost <NSObject>
- (void)imageIntrinsicSize:(CGSize)size forUrl:(NSString *)url;
- (BOOL)isSpoilerRevealed:(NSInteger)spoilerId;
- (void)toggleSpoiler:(NSInteger)spoilerId;
- (void)linkPressed:(NSString *)url;
- (void)linkLongPressed:(NSString *)url;
- (void)imagePressed:(NSString *)url;
@end

NS_ASSUME_NONNULL_END
