#import <UIKit/UIKit.h>

#import "../render/FMDBlock.h"
#import "FMDMarkdownHost.h"

NS_ASSUME_NONNULL_BEGIN

/// Draws one block's attributed string (TextKit) plus spoiler covers, and
/// hit-tests links, mentions, and spoilers by character range.
@interface FMDBlockTextView : UIView

@property (nonatomic, copy, nullable) NSAttributedString *attributedText;
@property (nonatomic, weak, nullable) id<FMDMarkdownHost> host;
@property (nonatomic, strong, nullable) UIColor *spoilerColor;
@property (nonatomic, assign) CGFloat spoilerRadius;

@end

NS_ASSUME_NONNULL_END
