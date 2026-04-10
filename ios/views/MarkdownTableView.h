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

@end

NS_ASSUME_NONNULL_END
