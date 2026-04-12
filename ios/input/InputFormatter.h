#import <UIKit/UIKit.h>

@class FormattingStore;
@class StyleConfig;

NS_ASSUME_NONNULL_BEGIN

@interface InputFormatter : NSObject

@property (nonatomic, strong) StyleConfig *styleConfig;
@property (nonatomic, strong) UIFont *baseFont;
@property (nonatomic, strong) UIColor *baseColor;
@property (nonatomic) CGFloat baseLineHeight;
@property (nonatomic) CGFloat paragraphSpacing;

/// Full re-style: resets everything to base attributes, then
/// layers on block and inline formatting. Used for import and
/// style prop changes.
- (void)applyAllFormatting:(FormattingStore *)store
             toTextStorage:(NSTextStorage *)textStorage;

/// Incremental re-style: resets only the given range to base
/// attributes (preserving MDBlockType), then re-applies block
/// and inline formatting that intersect the range. Used for
/// per-keystroke updates from dirty ranges.
- (void)applyFormattingInRange:(NSRange)dirtyRange
                         store:(FormattingStore *)store
                 toTextStorage:(NSTextStorage *)textStorage;

@end

NS_ASSUME_NONNULL_END
