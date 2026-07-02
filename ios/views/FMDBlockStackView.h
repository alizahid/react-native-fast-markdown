#import <UIKit/UIKit.h>

#import "../render/FMDBlock.h"

NS_ASSUME_NONNULL_BEGIN

/// Vertical stack of measured blocks; frames come from the measured tree.
@interface FMDBlockStackView : UIView

/// Bubbles image intrinsic sizes (url, pt w, pt h) up to the host view.
@property (nonatomic, copy, nullable) void (^onImageIntrinsicSize)
    (NSString *url, CGFloat width, CGFloat height);

- (void)setBlocks:(NSArray<FMDMeasuredBlock *> *)blocks gap:(CGFloat)gap;

@end

NS_ASSUME_NONNULL_END
