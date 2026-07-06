#import <UIKit/UIKit.h>

#import "../style/FMDLayoutStyle.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FMDBlockKind) {
  FMDBlockKindText,
  FMDBlockKindCode,
  FMDBlockKindQuote,
  FMDBlockKindList,
  FMDBlockKindDivider,
  FMDBlockKindImage,
  FMDBlockKindTable,
};

@class FMDBlock;

/// Custom attributed-string keys carrying interaction data.
FOUNDATION_EXPORT NSAttributedStringKey const FMDLinkURLAttributeName;
FOUNDATION_EXPORT NSAttributedStringKey const FMDSpoilerIDAttributeName;
/// Drawn run background ("chip"): value is an FMDRunBackground. Replaces
/// NSBackgroundColor, whose rect misaligns under custom line heights.
FOUNDATION_EXPORT NSAttributedStringKey const FMDRunBackgroundAttributeName;

/// Geometry + fill for a drawn run background.
@interface FMDRunBackground : NSObject
@property (nonatomic, strong) UIColor *color;
@property (nonatomic, assign) CGFloat radius;
@property (nonatomic, assign) BOOL continuousCurve;
@property (nonatomic, assign) CGFloat padLeft;
@property (nonatomic, assign) CGFloat padRight;
@end

@interface FMDListRow : NSObject
@property (nonatomic, strong) NSAttributedString *marker;
@property (nonatomic, strong) NSArray<FMDBlock *> *content;
@end

@interface FMDTableRow : NSObject
@property (nonatomic, assign) BOOL isHeader;
@property (nonatomic, strong) NSArray<NSAttributedString *> *cells;
@end

/// One renderable block; blocks nest (quote children, list row content).
@interface FMDBlock : NSObject
@property (nonatomic, assign) FMDBlockKind kind;
@property (nonatomic, strong, nullable) NSAttributedString *attributedText;
// Text blocks: spoiler cover styling.
@property (nonatomic, strong, nullable) UIColor *spoilerColor;
@property (nonatomic, assign) CGFloat spoilerRadius;
@property (nonatomic, assign) BOOL spoilerContinuous;
@property (nonatomic, strong, nullable) FMDLayoutStyle *layoutStyle;
@property (nonatomic, strong, nullable) NSArray<FMDBlock *> *children;
@property (nonatomic, strong, nullable) NSArray<FMDListRow *> *rows;
@property (nonatomic, assign) CGFloat listMarginLeft;
@property (nonatomic, assign) CGFloat markerWidth;
@property (nonatomic, assign) CGFloat markerMarginLeft;
@property (nonatomic, strong, nullable) UIColor *dividerColor;
@property (nonatomic, assign) CGFloat dividerThickness;

// Table blocks. Header/body row styles layer tableHeaderRow/tableBodyRow
// over the shared tableRow base; header cells fall back to the body cell
// padding key-by-key.
@property (nonatomic, strong, nullable) NSArray<FMDTableRow *> *tableRows;
@property (nonatomic, strong, nullable) FMDLayoutStyle *headerRowStyle;
@property (nonatomic, strong, nullable) FMDLayoutStyle *bodyRowStyle;
@property (nonatomic, assign) UIEdgeInsets cellPadding;
@property (nonatomic, assign) UIEdgeInsets headerCellPadding;
@property (nonatomic, assign) CGFloat minColumnWidth;
@property (nonatomic, assign) CGFloat maxColumnWidth;

// Image blocks.
@property (nonatomic, copy, nullable) NSString *imageUrl;
@property (nonatomic, strong, nullable) UIColor *imageBackground;
@property (nonatomic, assign) CGFloat imageBorderRadius;
@property (nonatomic, assign) CGFloat imageHeight;
@property (nonatomic, assign) CGFloat imageMaxHeight;
@property (nonatomic, assign) CGFloat imagePlaceholder;
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
/// Tables: resolved column widths and per-row heights.
@property (nonatomic, strong) NSArray<NSNumber *> *columnWidths;
@property (nonatomic, strong) NSArray<NSNumber *> *rowHeights;
@end

NS_ASSUME_NONNULL_END
