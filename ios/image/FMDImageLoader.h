#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Dependency-free image pipeline: request de-duplication, memory cache,
/// disk cache. Requests are owned by URL, not by views — recycling a view
/// only detaches its listener. Callbacks fire on the main thread.
@interface FMDImageLoader : NSObject

+ (nullable UIImage *)cachedImageForUrl:(NSString *)url;

+ (void)loadUrl:(NSString *)url completion:(void (^)(UIImage *_Nullable image))completion;

@end

NS_ASSUME_NONNULL_END
