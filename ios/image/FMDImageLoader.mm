#import "FMDImageLoader.h"

#import <CommonCrypto/CommonDigest.h>

static const unsigned long long kDiskCacheLimitBytes = 100ull * 1024 * 1024;

@implementation FMDImageLoader

+ (NSCache<NSString *, UIImage *> *)memoryCache {
  static NSCache<NSString *, UIImage *> *cache;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    cache = [NSCache new];
    cache.totalCostLimit = 64 * 1024 * 1024;
  });
  return cache;
}

+ (NSMutableDictionary<NSString *, NSMutableArray *> *)inFlight {
  static NSMutableDictionary *requests;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    requests = [NSMutableDictionary new];
  });
  return requests;
}

+ (nullable UIImage *)cachedImageForUrl:(NSString *)url {
  return [[self memoryCache] objectForKey:url];
}

+ (NSString *)diskPathForUrl:(NSString *)url {
  const char *bytes = url.UTF8String;
  unsigned char digest[CC_SHA256_DIGEST_LENGTH];
  CC_SHA256(bytes, (CC_LONG)strlen(bytes), digest);
  NSMutableString *name = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
  for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
    [name appendFormat:@"%02x", digest[i]];
  }
  NSString *directory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)
                             .firstObject stringByAppendingPathComponent:@"fastmarkdown_images"];
  [NSFileManager.defaultManager createDirectoryAtPath:directory
                          withIntermediateDirectories:YES
                                           attributes:nil
                                                error:nil];
  return [directory stringByAppendingPathComponent:name];
}

+ (void)loadUrl:(NSString *)url completion:(void (^)(UIImage *_Nullable))completion {
  UIImage *cached = [[self memoryCache] objectForKey:url];
  if (cached != nil) {
    completion(cached);
    return;
  }

  @synchronized(self) {
    NSMutableArray *listeners = [self inFlight][url];
    if (listeners != nil) {
      [listeners addObject:[completion copy]];
      return;
    }
    [self inFlight][url] = [NSMutableArray arrayWithObject:[completion copy]];
  }

  dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
    NSString *diskPath = [self diskPathForUrl:url];
    UIImage *image = [UIImage imageWithContentsOfFile:diskPath];

    if (image == nil) {
      NSURL *remote = [NSURL URLWithString:url];
      if (remote != nil) {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        __block NSData *downloaded = nil;
        NSURLSessionDataTask *task = [NSURLSession.sharedSession
            dataTaskWithURL:remote
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
            if (error == nil && data.length > 0 &&
                (![http isKindOfClass:[NSHTTPURLResponse class]] ||
                 (http.statusCode >= 200 && http.statusCode < 300))) {
              downloaded = data;
            }
            dispatch_semaphore_signal(semaphore);
          }];
        [task resume];
        dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC));
        if (downloaded != nil) {
          [downloaded writeToFile:diskPath atomically:YES];
          [self trimDiskCache];
          image = [UIImage imageWithData:downloaded];
        }
      }
    }

    if (image != nil) {
      const NSUInteger cost =
          (NSUInteger)(image.size.width * image.size.height * image.scale * image.scale * 4);
      [[self memoryCache] setObject:image forKey:url cost:cost];
    }

    NSArray *listeners;
    @synchronized(self) {
      listeners = [self inFlight][url];
      [[self inFlight] removeObjectForKey:url];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      for (void (^listener)(UIImage *) in listeners) {
        listener(image);
      }
    });
  });
}

+ (void)trimDiskCache {
  NSString *directory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)
                             .firstObject stringByAppendingPathComponent:@"fastmarkdown_images"];
  NSFileManager *fileManager = NSFileManager.defaultManager;
  NSArray<NSString *> *files = [fileManager contentsOfDirectoryAtPath:directory error:nil];

  unsigned long long total = 0;
  NSMutableArray<NSDictionary *> *entries = [NSMutableArray new];
  for (NSString *file in files) {
    NSString *path = [directory stringByAppendingPathComponent:file];
    NSDictionary *attributes = [fileManager attributesOfItemAtPath:path error:nil];
    total += attributes.fileSize;
    [entries addObject:@{
      @"path" : path,
      @"size" : @(attributes.fileSize),
      @"date" : attributes.fileModificationDate ?: NSDate.distantPast,
    }];
  }
  if (total <= kDiskCacheLimitBytes) {
    return;
  }
  [entries sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
    return [a[@"date"] compare:b[@"date"]];
  }];
  for (NSDictionary *entry in entries) {
    [fileManager removeItemAtPath:entry[@"path"] error:nil];
    total -= [entry[@"size"] unsignedLongLongValue];
    if (total <= kDiskCacheLimitBytes) {
      break;
    }
  }
}

@end
