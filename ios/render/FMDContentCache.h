#import <Foundation/Foundation.h>

#import "FMDRenderedContent.h"

NS_ASSUME_NONNULL_BEGIN

/// Shared parse/render cache. The Fabric measurer populates it on the layout
/// thread; the mounted view reads the same entry on the main thread.
@interface FMDContentCache : NSObject

+ (FMDRenderedContent *)contentForMarkdown:(NSString *)markdown
                                stylesJson:(NSString *)stylesJson
                                 fontScale:(CGFloat)fontScale;

@end

NS_ASSUME_NONNULL_END
