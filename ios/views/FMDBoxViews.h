#import <UIKit/UIKit.h>

#import "../render/FMDBlock.h"

NS_ASSUME_NONNULL_BEGIN

/// Block quote: paints its box style, hosts a nested stack inside padding.
@interface FMDQuoteView : UIView
- (void)bind:(FMDMeasuredBlock *)measured gap:(CGFloat)gap;
@end

/// Code block: paints its box, hosts unwrapped text in a horizontal scroller.
@interface FMDCodeBlockView : UIView
- (void)bind:(FMDMeasuredBlock *)measured;
@end

/// List: rows of a fixed-width marker column and nested content stacks.
@interface FMDListBlockView : UIView
- (void)bind:(FMDMeasuredBlock *)measured gap:(CGFloat)gap;
@end

NS_ASSUME_NONNULL_END
