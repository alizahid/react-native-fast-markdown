#import <UIKit/UIKit.h>

@class RenderContext;

NS_ASSUME_NONNULL_BEGIN

// Forward declare the C++ AST node wrapper
@class ASTNodeWrapper;

@protocol NodeRenderer <NSObject>

- (void)renderNode:(ASTNodeWrapper *)node
              into:(NSMutableAttributedString *)output
           context:(RenderContext *)context;

@end

NS_ASSUME_NONNULL_END
