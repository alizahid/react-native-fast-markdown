#import <UIKit/UIKit.h>

#import "../render/FMDBlock.h"
#import "FMDMarkdownHost.h"

NS_ASSUME_NONNULL_BEGIN

/// One markdown image: rounded-corner aspect-fit bitmap, background while
/// loading. Requests are URL-owned; this view only listens.
@interface FMDImageView : UIView

@property (nonatomic, weak, nullable) id<FMDMarkdownHost> host;

- (void)bind:(FMDBlock *)block;

@end

NS_ASSUME_NONNULL_END
