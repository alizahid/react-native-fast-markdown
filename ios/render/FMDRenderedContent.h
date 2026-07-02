#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Parsed + rendered markdown blocks, shared between the Fabric measurer
/// (layout thread) and the mounted view (main thread). Per-width layout
/// results are cached.
@interface FMDRenderedContent : NSObject

@property (nonatomic, readonly) NSArray<NSAttributedString *> *blocks;

- (instancetype)initWithBlocks:(NSArray<NSAttributedString *> *)blocks
                           gap:(CGFloat)gap
               verticalPadding:(CGFloat)verticalPadding;

- (NSArray<NSNumber *> *)blockHeightsForWidth:(CGFloat)width;
- (CGFloat)totalHeightForWidth:(CGFloat)width;

@end

NS_ASSUME_NONNULL_END
