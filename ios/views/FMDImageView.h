#import <UIKit/UIKit.h>

#import "../render/FMDBlock.h"

NS_ASSUME_NONNULL_BEGIN

/// One markdown image: rounded-corner aspect-fit bitmap, background while
/// loading. Requests are URL-owned; this view only listens.
@interface FMDImageView : UIView

/// Fires once with the intrinsic point size when the image arrives.
@property (nonatomic, copy, nullable) void (^onIntrinsicSize)
    (NSString *url, CGFloat width, CGFloat height);

- (void)bind:(FMDBlock *)block;

@end

NS_ASSUME_NONNULL_END
