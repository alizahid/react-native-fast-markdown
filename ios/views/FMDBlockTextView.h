#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Draws one block's attributed string with the same TextKit path used for
/// measurement, keeping measured and rendered heights identical.
@interface FMDBlockTextView : UIView

@property (nonatomic, copy, nullable) NSAttributedString *attributedText;

@end

NS_ASSUME_NONNULL_END
