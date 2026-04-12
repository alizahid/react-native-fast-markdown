#import <UIKit/UIKit.h>

@class FormattingStore;
@class StyleConfig;

NS_ASSUME_NONNULL_BEGIN

/// Transparent overlay that draws block-level decorations
/// (background fills, left borders, rounded corners) for
/// blockquotes and code blocks. Positioned over the UITextView
/// and updated after each formatting pass.
@interface BlockDecorationView : UIView

- (void)updateDecorationsForTextView:(UITextView *)textView
                               store:(FormattingStore *)store
                         styleConfig:(StyleConfig *)styleConfig;

@end

NS_ASSUME_NONNULL_END
