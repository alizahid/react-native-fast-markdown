#import <Foundation/Foundation.h>
#import "NodeRenderer.h"
#import "ASTNodeWrapper.h"

NS_ASSUME_NONNULL_BEGIN

@interface RendererFactory : NSObject

+ (nullable id<NodeRenderer>)rendererForNode:(ASTNodeWrapper *)node;

@end

NS_ASSUME_NONNULL_END
