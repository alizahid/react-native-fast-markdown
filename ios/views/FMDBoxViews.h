#import <UIKit/UIKit.h>

#import "../render/FMDBlock.h"
#import "FMDMarkdownHost.h"

NS_ASSUME_NONNULL_BEGIN

/// Horizontal scroller for code blocks and tables. Cancels React's surface
/// touch handler when a drag begins so a wrapping Pressable's press dies,
/// exactly like React Native's own scroll views.
@interface FMDNestedScrollView : UIScrollView <UIScrollViewDelegate>
@end

/// Block quote: paints its box style, hosts a nested stack inside padding.
@interface FMDQuoteView : UIView
- (void)bind:(FMDMeasuredBlock *)measured
         gap:(CGFloat)gap
        host:(nullable id<FMDMarkdownHost>)host;
@end

/// Code block: paints its box, hosts unwrapped text in a horizontal scroller.
@interface FMDCodeBlockView : UIView
- (void)bind:(FMDMeasuredBlock *)measured;
@end

/// List: rows of a fixed-width marker column and nested content stacks.
@interface FMDListBlockView : UIView
- (void)bind:(FMDMeasuredBlock *)measured
         gap:(CGFloat)gap
        host:(nullable id<FMDMarkdownHost>)host;
@end

NS_ASSUME_NONNULL_END
