#import <Foundation/Foundation.h>

#import "../style/FMDStyleConfig.h"
#import "FMDBlock.h"

NS_ASSUME_NONNULL_BEGIN

/// AST -> renderable block tree (attribute-stack inline rendering).
@interface FMDBlockRenderer : NSObject

+ (NSArray<FMDBlock *> *)renderMarkdown:(NSString *)markdown
                                 styles:(FMDStyleConfig *)styles
                              fontScale:(CGFloat)fontScale;

@end

NS_ASSUME_NONNULL_END
