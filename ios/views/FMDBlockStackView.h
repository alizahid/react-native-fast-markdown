#import <UIKit/UIKit.h>

#import "../render/FMDBlock.h"

#import "FMDMarkdownHost.h"

NS_ASSUME_NONNULL_BEGIN

/// Vertical stack of measured blocks; frames come from the measured tree.
@interface FMDBlockStackView : UIView

@property (nonatomic, weak, nullable) id<FMDMarkdownHost> host;

- (void)setBlocks:(NSArray<FMDMeasuredBlock *> *)blocks gap:(CGFloat)gap;

@end

NS_ASSUME_NONNULL_END
