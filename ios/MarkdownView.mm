#import "MarkdownView.h"

#import <React/RCTConversions.h>
#import <React/RCTFabricComponentsPlugins.h>

// Custom descriptor with our shadow node (state + measureContent)
#import "MarkdownViewComponentDescriptor.h"
#import "MarkdownViewState.h"
#import <react/renderer/components/MarkdownViewSpec/EventEmitters.h>
#import <react/renderer/components/MarkdownViewSpec/Props.h>

#import "ASTNodeWrapper.h"
#import "MarkdownParser.hpp"
#import "RenderContext.h"
#import "RendererFactory.h"
#import "StyleConfig.h"

using namespace facebook::react;

static const NSUInteger kMaxCacheSize = 128;

@interface MarkdownView () <UITextViewDelegate>
@end

@implementation MarkdownView {
  UITextView *_textView;
  NSString *_currentMarkdown;
  NSString *_currentStyleJSON;
  NSArray<NSString *> *_customTags;
  StyleConfig *_styleConfig;

  NSMutableDictionary<NSString *, NSAttributedString *> *_renderCache;
  NSMutableArray<NSString *> *_cacheOrder;

  dispatch_queue_t _parseQueue;
  int64_t _heightUpdateCounter;

  // Fabric state handle for native-driven measurement
  MarkdownViewShadowNode::ConcreteState::Shared _fabricState;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<MarkdownViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _textView = [[UITextView alloc] initWithFrame:self.bounds];
    _textView.editable = NO;
    _textView.scrollEnabled = NO;
    _textView.textContainerInset = UIEdgeInsetsZero;
    _textView.textContainer.lineFragmentPadding = 0;
    _textView.backgroundColor = [UIColor clearColor];
    _textView.delegate = self;
    _textView.dataDetectorTypes = UIDataDetectorTypeNone;
    [self addSubview:_textView];

    _renderCache = [NSMutableDictionary new];
    _cacheOrder = [NSMutableArray new];
    _parseQueue =
        dispatch_queue_create("com.markdown.parse", DISPATCH_QUEUE_SERIAL);
    _heightUpdateCounter = 0;
  }
  return self;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  _textView.frame = self.bounds;
}

- (void)updateState:(const facebook::react::State::Shared &)state
           oldState:(const facebook::react::State::Shared &)oldState {
  _fabricState = std::static_pointer_cast<
      const MarkdownViewShadowNode::ConcreteState>(state);
}

- (void)updateContentMeasurement {
  if (!_fabricState) return;

  CGFloat width = self.bounds.size.width > 0
      ? self.bounds.size.width
      : UIScreen.mainScreen.bounds.size.width;
  CGSize size = [_textView sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];

  _heightUpdateCounter++;

  auto newData = _fabricState->getData();
  newData.heightUpdateCounter = _heightUpdateCounter;
  newData.measuredHeight = static_cast<float>(size.height);
  newData.measuredWidth = static_cast<float>(size.width);
  _fabricState->updateState(std::move(newData));
}

- (void)updateProps:(const Props::Shared &)props
           oldProps:(const Props::Shared &)oldProps {
  const auto &newViewProps =
      *std::static_pointer_cast<const MarkdownViewProps>(props);

  NSString *markdown =
      [NSString stringWithUTF8String:newViewProps.markdown.c_str()];
  NSString *styleJSON = newViewProps.markdownStyle.empty()
                            ? @""
                            : [NSString stringWithUTF8String:newViewProps.markdownStyle.c_str()];

  NSMutableArray<NSString *> *customTags = [NSMutableArray new];
  for (const auto &tag : newViewProps.customTags) {
    [customTags addObject:[NSString stringWithUTF8String:tag.c_str()]];
  }

  BOOL markdownChanged =
      ![markdown isEqualToString:_currentMarkdown ?: @""];
  BOOL styleChanged =
      ![styleJSON isEqualToString:_currentStyleJSON ?: @""];

  _currentMarkdown = markdown;
  _currentStyleJSON = styleJSON;
  _customTags = customTags;

  if (styleChanged) {
    _styleConfig = [StyleConfig fromJSON:styleJSON];
    [_renderCache removeAllObjects];
    [_cacheOrder removeAllObjects];
  }

  if (markdownChanged || styleChanged) {
    [self renderMarkdown];
  }

  [super updateProps:props oldProps:oldProps];
}

- (void)renderMarkdown {
  NSString *markdown = _currentMarkdown;
  if (!markdown || markdown.length == 0) {
    _textView.attributedText = [[NSAttributedString alloc] initWithString:@""];
    return;
  }

  NSString *cacheKey =
      [NSString stringWithFormat:@"%@_%@", markdown, _currentStyleJSON];
  NSAttributedString *cached = _renderCache[cacheKey];
  if (cached) {
    _textView.attributedText = cached;
    [self updateContentMeasurement];
    return;
  }

  StyleConfig *styleConfig = _styleConfig ?: [StyleConfig fromJSON:@""];
  NSArray<NSString *> *customTags = [_customTags copy];

  if (markdown.length < 500) {
    NSAttributedString *result =
        [self buildAttributedString:markdown
                        styleConfig:styleConfig
                         customTags:customTags];
    [self cacheResult:result forKey:cacheKey];
    _textView.attributedText = result;
    [self updateContentMeasurement];
    return;
  }

  __weak typeof(self) weakSelf = self;
  dispatch_async(_parseQueue, ^{
    NSAttributedString *result =
        [weakSelf buildAttributedString:markdown
                            styleConfig:styleConfig
                             customTags:customTags];
    dispatch_async(dispatch_get_main_queue(), ^{
      __strong typeof(weakSelf) strongSelf = weakSelf;
      if (!strongSelf) return;
      if (![markdown isEqualToString:strongSelf->_currentMarkdown]) return;

      [strongSelf cacheResult:result forKey:cacheKey];
      strongSelf->_textView.attributedText = result;
      [strongSelf updateContentMeasurement];
    });
  });
}

- (NSAttributedString *)buildAttributedString:(NSString *)markdown
                                  styleConfig:(StyleConfig *)styleConfig
                                   customTags:(NSArray<NSString *> *)customTags {
  markdown::ParseOptions options;
  options.enableTables = true;
  options.enableStrikethrough = true;
  options.enableTaskLists = true;
  options.enableAutolinks = true;

  for (NSString *tag in customTags) {
    options.customTags.insert(std::string([tag UTF8String]));
  }

  std::string markdownStr([markdown UTF8String]);
  markdown::ASTNode ast = markdown::MarkdownParser::parse(markdownStr, options);

  ASTNodeWrapper *rootWrapper =
      [[ASTNodeWrapper alloc] initWithOpaqueNode:&ast];

  RenderContext *context = [[RenderContext alloc] init];
  context.styleConfig = styleConfig;
  context.customTags = [NSSet setWithArray:customTags];

  NSMutableAttributedString *output = [[NSMutableAttributedString alloc] init];
  [context renderChildren:rootWrapper into:output];

  if (output.length > 0) {
    unichar lastChar = [output.string characterAtIndex:output.length - 1];
    if (lastChar == '\n') {
      [output deleteCharactersInRange:NSMakeRange(output.length - 1, 1)];
    }
  }

  return [output copy];
}

- (void)cacheResult:(NSAttributedString *)result forKey:(NSString *)key {
  _renderCache[key] = result;
  [_cacheOrder addObject:key];

  while (_cacheOrder.count > kMaxCacheSize) {
    NSString *oldKey = _cacheOrder.firstObject;
    [_cacheOrder removeObjectAtIndex:0];
    [_renderCache removeObjectForKey:oldKey];
  }
}

#pragma mark - UITextViewDelegate

- (BOOL)textView:(UITextView *)textView
    shouldInteractWithURL:(NSURL *)URL
                  inRange:(NSRange)characterRange
              interaction:(UITextItemInteraction)interaction {
  const auto &eventEmitter =
      static_cast<const MarkdownViewEventEmitter &>(*_eventEmitter);

  if (interaction == UITextItemInteractionInvokeDefaultAction) {
    eventEmitter.onLinkPress({
        .url = std::string([[URL absoluteString] UTF8String]),
        .title = std::string(""),
    });
  } else if (interaction == UITextItemInteractionPresentActions) {
    eventEmitter.onLinkLongPress({
        .url = std::string([[URL absoluteString] UTF8String]),
        .title = std::string(""),
    });
  }

  return NO;
}

@end

Class<RCTComponentViewProtocol> MarkdownViewCls(void) {
  return MarkdownView.class;
}
