#import <UIKit/UIKit.h>

#import "../style/FMDLayoutStyle.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FMDBlockKind) {
  FMDBlockKindText,
  FMDBlockKindCode,
  FMDBlockKindQuote,
  FMDBlockKindList,
  FMDBlockKindDivider,
};

@class FMDBlock;

@interface FMDListRow : NSObject
@property (nonatomic, strong) NSAttributedString *marker;
@property (nonatomic, strong) NSArray<FMDBlock *> *content;
@end

/// One renderable block; blocks nest (quote children, list row content).
@interface FMDBlock : NSObject
@property (nonatomic, assign) FMDBlockKind kind;
@property (nonatomic, strong, nullable) NSAttributedString *attributedText;
@property (nonatomic, strong, nullable) FMDLayoutStyle *layoutStyle;
@property (nonatomic, strong, nullable) NSArray<FMDBlock *> *children;
@property (nonatomic, strong, nullable) NSArray<FMDListRow *> *rows;
@property (nonatomic, assign) CGFloat listMarginLeft;
@property (nonatomic, assign) CGFloat markerWidth;
@property (nonatomic, assign) CGFloat markerMarginLeft;
@property (nonatomic, strong, nullable) UIColor *dividerColor;
@property (nonatomic, assign) CGFloat dividerThickness;
@end

/// Layout results for one block at one width.
@interface FMDMeasuredBlock : NSObject
@property (nonatomic, strong) FMDBlock *block;
@property (nonatomic, assign) CGFloat height;
/// Code: unwrapped content width for the scroller; Text: wrapped text height.
@property (nonatomic, assign) CGFloat contentWidth;
@property (nonatomic, assign) CGFloat textHeight;
@property (nonatomic, strong) NSArray<FMDMeasuredBlock *> *children;
@property (nonatomic, strong) NSArray<NSNumber *> *markerHeights;
@property (nonatomic, strong) NSArray<NSArray<FMDMeasuredBlock *> *> *rowContents;
@end

NS_ASSUME_NONNULL_END
