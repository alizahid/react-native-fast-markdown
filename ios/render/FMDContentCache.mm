#import "FMDContentCache.h"

#import "../style/FMDStyleConfig.h"
#import "FMDBlockRenderer.h"

@implementation FMDContentCache

+ (FMDRenderedContent *)contentForMarkdown:(NSString *)markdown
                                stylesJson:(NSString *)stylesJson
                                 fontScale:(CGFloat)fontScale {
  static NSCache<NSString *, FMDRenderedContent *> *cache;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    cache = [NSCache new];
    cache.countLimit = 64;
  });

  NSString *key = [NSString stringWithFormat:@"%lu\x1f%lu\x1f%.3f",
                                             (unsigned long)markdown.hash,
                                             (unsigned long)stylesJson.hash,
                                             fontScale];
  FMDRenderedContent *cached = [cache objectForKey:key];
  if (cached != nil) {
    return cached;
  }

  FMDStyleConfig *styles = [FMDStyleConfig configWithJson:stylesJson];
  NSArray<FMDBlock *> *blocks = [FMDBlockRenderer renderMarkdown:markdown
                                                          styles:styles
                                                       fontScale:fontScale];
  FMDRenderedContent *content = [[FMDRenderedContent alloc] initWithBlocks:blocks
                                                                       gap:styles.gap
                                                                topPadding:styles.paddingTop
                                                             bottomPadding:styles.paddingBottom];
  [cache setObject:content forKey:key];
  return content;
}

@end
