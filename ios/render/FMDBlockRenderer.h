#import <Foundation/Foundation.h>

#import "../style/FMDStyleConfig.h"

NS_ASSUME_NONNULL_BEGIN

/// AST -> attributed-string blocks. M1 handles paragraph/heading text with
/// basic bold/italic; the full element set arrives with M2/M3.
@interface FMDBlockRenderer : NSObject

+ (NSArray<NSAttributedString *> *)renderMarkdown:(NSString *)markdown
                                           styles:(FMDStyleConfig *)styles
                                        fontScale:(CGFloat)fontScale;

@end

NS_ASSUME_NONNULL_END
