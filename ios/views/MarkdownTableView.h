#import <UIKit/UIKit.h>

@class ASTNodeWrapper;
@class StyleConfig;

NS_ASSUME_NONNULL_BEGIN

/// A horizontally scrollable table view built from a markdown table AST node.
/// Renders header row with distinct background, data rows with optional
/// alternating colors, and cell borders.
@interface MarkdownTableView : UIScrollView

- (instancetype)initWithTableNode:(ASTNodeWrapper *)tableNode
                      styleConfig:(StyleConfig *)styleConfig
                         maxWidth:(CGFloat)maxWidth;

/// Total height of the rendered table (for parent layout).
@property (nonatomic, readonly) CGFloat tableHeight;

/// Computes the fully laid-out size of a table AST node without
/// instantiating a view. Thread-safe — intended for calls from the
/// Fabric shadow tree during measureContent. Shares the cell rendering
/// + column-width / row-height pipeline with the instance initializer.
+ (CGSize)sizeForTableNode:(ASTNodeWrapper *)tableNode
               styleConfig:(StyleConfig *)styleConfig
                  maxWidth:(CGFloat)maxWidth;

@end

NS_ASSUME_NONNULL_END
