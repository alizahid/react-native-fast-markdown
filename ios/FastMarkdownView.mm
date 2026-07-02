#import "FastMarkdownView.h"

#import <React/RCTConversions.h>

#import <react/renderer/components/FastMarkdownViewSpec/EventEmitters.h>
#import <react/renderer/components/FastMarkdownViewSpec/Props.h>
#import <react/renderer/core/ConcreteComponentDescriptor.h>

// Imported directly (not via the override ComponentDescriptors.h) so the
// custom measurable shadow node is used regardless of header search order.
#import "react/FastMarkdownShadowNode.h"

namespace facebook::react {
using FMDComponentDescriptor = ConcreteComponentDescriptor<FastMarkdownShadowNode>;
} // namespace facebook::react

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
  // url -> @[w, h] points: from the images prop (wins) and loaded bitmaps.
  NSMutableDictionary<NSString *, NSArray<NSNumber *> *> *_propImageSizes;
  NSMutableDictionary<NSString *, NSArray<NSNumber *> *> *_loadedImageSizes;
  FastMarkdownShadowNode::ConcreteState::Shared _state;
}

+ (void)load {
  fastmarkdown::FastMarkdownMeasurer::shared().install(
      [](const std::string &markdown,
         const std::string &stylesJson,
         const std::string &imagesJson,
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
        NSString *imagesString =
            [[NSString alloc] initWithBytes:imagesJson.data()
                                     length:imagesJson.size()
                                   encoding:NSUTF8StringEncoding];
        return [FMDMarkdownMeasurer measureMarkdown:markdownString ?: @""
                                         stylesJson:stylesString ?: @""
                                         imagesJson:imagesString ?: @""
                                           maxWidth:maxWidth
                                          fontScale:fontScale];
      });
}

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<FMDComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const FastMarkdownViewProps>();
    _props = defaultProps;
    _markdown = @"";
    _stylesJson = @"";
    _stack = [[FMDBlockStackView alloc] initWithFrame:CGRectZero];
    _propImageSizes = [NSMutableDictionary new];
    _loadedImageSizes = [NSMutableDictionary new];
    __weak FastMarkdownView *weakSelf = self;
    _stack.onImageIntrinsicSize = ^(NSString *url, CGFloat width, CGFloat height) {
      [weakSelf noteIntrinsicSize:CGSizeMake(width, height) forUrl:url];
    };
    [self addSubview:_stack];
  }
  return self;
}

- (void)noteIntrinsicSize:(CGSize)size forUrl:(NSString *)url {
  if (_propImageSizes[url] != nil || _loadedImageSizes[url] != nil) {
    return;
  }
  _loadedImageSizes[url] = @[ @(size.width), @(size.height) ];

  // Publish into the shadow-node state so measure() grows the component.
  if (_state != nullptr) {
    std::map<std::string, FastMarkdownState::ImageSize> sizes;
    for (NSString *key in _loadedImageSizes) {
      NSArray<NSNumber *> *value = _loadedImageSizes[key];
      sizes[std::string(key.UTF8String ?: "")] = FastMarkdownState::ImageSize{
          value[0].doubleValue, value[1].doubleValue};
    }
    _state->updateState(FastMarkdownState(std::move(sizes)));
  }
  [self setNeedsLayout];
}

- (void)updateState:(const State::Shared &)state oldState:(const State::Shared &)oldState {
  _state = std::static_pointer_cast<const FastMarkdownShadowNode::ConcreteState>(state);
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

  [_propImageSizes removeAllObjects];
  for (const auto &image : newViewProps.images) {
    NSString *url = [[NSString alloc] initWithBytes:image.url.data()
                                             length:image.url.size()
                                           encoding:NSUTF8StringEncoding];
    if (url != nil) {
      _propImageSizes[url] = @[ @(image.width), @(image.height) ];
    }
  }

  [super updateProps:props oldProps:oldProps];
}

- (NSDictionary<NSString *, NSArray<NSNumber *> *> *)mergedImageSizes {
  if (_loadedImageSizes.count == 0 && _propImageSizes.count == 0) {
    return @{};
  }
  NSMutableDictionary *merged = [_loadedImageSizes mutableCopy];
  [merged addEntriesFromDictionary:_propImageSizes];
  return merged;
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
  _state = nullptr;
  [_propImageSizes removeAllObjects];
  [_loadedImageSizes removeAllObjects];
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
  NSDictionary *imageSizes = [self mergedImageSizes];
  FMDWidthLayout *layout = [content layoutForWidth:contentWidth imageSizes:imageSizes];

  NSString *key = [NSString stringWithFormat:@"%lu\x1f%lu\x1f%lu",
                                             (unsigned long)_markdown.hash,
                                             (unsigned long)_stylesJson.hash,
                                             (unsigned long)imageSizes.hash];
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
