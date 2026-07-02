#import <UIKit/UIKit.h>

#import "FMDBlock.h"

NS_ASSUME_NONNULL_BEGIN

@interface FMDWidthLayout : NSObject
@property (nonatomic, strong) NSArray<FMDMeasuredBlock *> *measured;
@property (nonatomic, assign) CGFloat totalHeight;
@end

/// Parsed + rendered markdown block tree, shared between the Fabric measurer
/// (layout thread) and the mounted view (main thread). Per-width layout
/// results are cached.
@interface FMDRenderedContent : NSObject

@property (nonatomic, readonly) CGFloat gap;

- (instancetype)initWithBlocks:(NSArray<FMDBlock *> *)blocks
                           gap:(CGFloat)gap
                    topPadding:(CGFloat)topPadding
                 bottomPadding:(CGFloat)bottomPadding;

- (FMDWidthLayout *)layoutForWidth:(CGFloat)width;

+ (CGFloat)stackHeight:(NSArray<FMDMeasuredBlock *> *)children gap:(CGFloat)gap;

@end

NS_ASSUME_NONNULL_END
