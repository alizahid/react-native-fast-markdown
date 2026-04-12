#import <UIKit/UIKit.h>

@class FormattingStore;
@class StyleConfig;

NS_ASSUME_NONNULL_BEGIN

@interface InputFormatter : NSObject

@property (nonatomic, strong) StyleConfig *styleConfig;
@property (nonatomic, strong) UIFont *baseFont;
@property (nonatomic, strong) UIColor *baseColor;

/// Re-applies all formatting from the store to the text storage.
/// Resets everything to base attributes first, then layers on
/// block and inline formatting.
- (void)applyAllFormatting:(FormattingStore *)store
             toTextStorage:(NSTextStorage *)textStorage;

@end

NS_ASSUME_NONNULL_END
