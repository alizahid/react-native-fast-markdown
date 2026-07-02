#import "FastMarkdownView.h"

#import <React/RCTConversions.h>

// Resolves to the override header (custom measurable shadow node); the
// override directory precedes generated headers in HEADER_SEARCH_PATHS.
#import <react/renderer/components/FastMarkdownViewSpec/ComponentDescriptors.h>
#import <react/renderer/components/FastMarkdownViewSpec/EventEmitters.h>
#import <react/renderer/components/FastMarkdownViewSpec/Props.h>

#import "RCTFabricComponentsPlugins.h"

#import "measure/FMDMarkdownMeasurer.h"
#import "render/FMDContentCache.h"
#import "style/FMDStyleConfig.h"
#import "views/FMDBlockStackView.h"

#import "react/FastMarkdownMeasurer.h"

using namespace facebook::react;

@implementation FastMarkdownView {
  NSString *_markdown;
  NSString *_stylesJson;
  FMDBlockStackView *_stack;
  NSString *_boundKey;
  CGFloat _boundWidth;
}

+ (void)load {
  fastmarkdown::FastMarkdownMeasurer::shared().install(
      [](const std::string &markdown,
         const std::string &stylesJson,
         float maxWidth,
         float fontScale) -> float {
        NSString *markdownString =
            [[NSString alloc] initWithBytes:markdown.data()
                                     length:markdown.size()
                                   encoding:NSUTF8StringEncoding];
        NSString *stylesString =
            [[NSString alloc] initWithBytes:stylesJson.data()
                                     length:stylesJson.size()
                                   encoding:NSUTF8StringEncoding];
        return [FMDMarkdownMeasurer measureMarkdown:markdownString ?: @""
                                         stylesJson:stylesString ?: @""
                                           maxWidth:maxWidth
                                          fontScale:fontScale];
      });
}

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<FastMarkdownViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const FastMarkdownViewProps>();
    _props = defaultProps;
    _markdown = @"";
    _stylesJson = @"";
    _stack = [[FMDBlockStackView alloc] initWithFrame:CGRectZero];
    [self addSubview:_stack];
  }
  return self;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &newViewProps = *std::static_pointer_cast<FastMarkdownViewProps const>(props);

  NSString *markdown =
      [[NSString alloc] initWithBytes:newViewProps.markdown.data()
                               length:newViewProps.markdown.size()
                             encoding:NSUTF8StringEncoding] ?: @"";
  NSString *stylesJson =
      [[NSString alloc] initWithBytes:newViewProps.stylesJson.data()
                               length:newViewProps.stylesJson.size()
                             encoding:NSUTF8StringEncoding] ?: @"";

  if (![markdown isEqualToString:_markdown] || ![stylesJson isEqualToString:_stylesJson]) {
    _markdown = markdown;
    _stylesJson = stylesJson;
    [self setNeedsLayout];
  }

  [super updateProps:props oldProps:oldProps];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  [self rebuildBlocks];
}

- (void)prepareForRecycle {
  [super prepareForRecycle];
  _markdown = @"";
  _stylesJson = @"";
  _boundKey = nil;
  [_stack setBlocks:@[] gap:0];
}

- (void)rebuildBlocks {
  FMDStyleConfig *styles = [FMDStyleConfig configWithJson:_stylesJson];
  self.backgroundColor = styles.backgroundColor ?: UIColor.clearColor;

  const CGFloat contentWidth =
      self.bounds.size.width - styles.paddingLeft - styles.paddingRight;
  if (contentWidth <= 0 || _markdown.length == 0) {
    [_stack setBlocks:@[] gap:0];
    _boundKey = nil;
    return;
  }

  // Pinned to 1.0 until allowFontScaling lands; must match the shadow node.
  const CGFloat fontScale = 1.0;
  FMDRenderedContent *content = [FMDContentCache contentForMarkdown:_markdown
                                                         stylesJson:_stylesJson
                                                          fontScale:fontScale];
  FMDWidthLayout *layout = [content layoutForWidth:contentWidth];

  NSString *key = [NSString stringWithFormat:@"%lu\x1f%lu",
                                             (unsigned long)_markdown.hash,
                                             (unsigned long)_stylesJson.hash];
  if (![key isEqualToString:_boundKey] || _boundWidth != contentWidth) {
    _boundKey = key;
    _boundWidth = contentWidth;
    [_stack setBlocks:layout.measured gap:content.gap];
  }

  const CGFloat contentHeight =
      layout.totalHeight - styles.paddingTop - styles.paddingBottom;
  _stack.frame =
      CGRectMake(styles.paddingLeft, styles.paddingTop, contentWidth, contentHeight);
}

@end
