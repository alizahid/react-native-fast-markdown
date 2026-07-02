#import "FMDMarkdownMeasurer.h"

#import "../render/FMDContentCache.h"
#import "../style/FMDStyleConfig.h"

@implementation FMDMarkdownMeasurer

+ (CGFloat)measureMarkdown:(NSString *)markdown
                stylesJson:(NSString *)stylesJson
                  maxWidth:(CGFloat)maxWidth
                 fontScale:(CGFloat)fontScale {
  FMDStyleConfig *styles = [FMDStyleConfig configWithJson:stylesJson];
  const CGFloat contentWidth = maxWidth - styles.paddingLeft - styles.paddingRight;
  if (contentWidth <= 0 || markdown.length == 0) {
    return 0;
  }

  FMDRenderedContent *content = [FMDContentCache contentForMarkdown:markdown
                                                         stylesJson:stylesJson
                                                          fontScale:fontScale];
  return [content layoutForWidth:contentWidth].totalHeight;
}

@end
