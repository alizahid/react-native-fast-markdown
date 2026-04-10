#import "MarkdownView.h"

#import <React/RCTConversions.h>
#import <React/RCTFabricComponentsPlugins.h>
#import <react/renderer/components/MarkdownViewSpec/ComponentDescriptors.h>
#import <react/renderer/components/MarkdownViewSpec/EventEmitters.h>
#import <react/renderer/components/MarkdownViewSpec/Props.h>

#import "ASTNodeWrapper.h"
#import "MarkdownParser.hpp"
#import "MarkdownSpoilerOverlay.h"
#import "MarkdownTableView.h"
#import "RenderContext.h"
#import "RendererFactory.h"
#import "StyleConfig.h"

using namespace facebook::react;

static const NSUInteger kMaxCacheSize = 128;

@interface MarkdownView () <UITextViewDelegate>
@end

@implementation MarkdownView {
  UIStackView *_stackView;
  NSString *_currentMarkdown;
  NSString *_currentStyleJSON;
  NSArray<NSString *> *_customTags;
  StyleConfig *_styleConfig;

  NSMutableDictionary<NSString *, NSNumber *> *_heightCache;
  NSMutableArray<NSString *> *_cacheOrder;

  dispatch_queue_t _parseQueue;
  BOOL _pendingSizeEmit;
  NSMutableArray<MarkdownSpoilerOverlay *> *_spoilerOverlays;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<MarkdownViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _stackView = [[UIStackView alloc] initWithFrame:self.bounds];
    _stackView.axis = UILayoutConstraintAxisVertical;
    _stackView.alignment = UIStackViewAlignmentFill;
    _stackView.spacing = 0;
    [self addSubview:_stackView];

    _heightCache = [NSMutableDictionary new];
    _cacheOrder = [NSMutableArray new];
    _parseQueue =
        dispatch_queue_create("com.markdown.parse", DISPATCH_QUEUE_SERIAL);
    _spoilerOverlays = [NSMutableArray new];
  }
  return self;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  _stackView.frame = self.bounds;

  if (self.bounds.size.width > 0 && _stackView.arrangedSubviews.count > 0) {
    [self emitContentSizeIfNeeded];
  }
}

- (void)updateEventEmitter:(const EventEmitter::Shared &)eventEmitter {
  [super updateEventEmitter:eventEmitter];

  if (_pendingSizeEmit && _stackView.arrangedSubviews.count > 0) {
    _pendingSizeEmit = NO;
    [self emitContentSizeIfNeeded];
  }
}

- (void)emitContentSizeIfNeeded {
  if (_stackView.arrangedSubviews.count == 0)
    return;

  if (!_eventEmitter) {
    _pendingSizeEmit = YES;
    return;
  }

  CGFloat width =
      self.bounds.size.width > 0
          ? self.bounds.size.width
          : UIScreen.mainScreen.bounds.size.width;

  CGSize size = [_stackView systemLayoutSizeFittingSize:
      CGSizeMake(width, UIView.layoutFittingCompressedSize.height)];

  const auto &eventEmitter =
      static_cast<const MarkdownViewEventEmitter &>(*_eventEmitter);
  eventEmitter.onContentSizeChange({
      .width = static_cast<double>(size.width),
      .height = static_cast<double>(size.height),
  });
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
    [_heightCache removeAllObjects];
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
    [self clearSegments];
    return;
  }

  StyleConfig *styleConfig = _styleConfig ?: [StyleConfig fromJSON:@""];
  NSArray<NSString *> *customTags = [_customTags copy];

  // Parse
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

  // Split AST children into segments: text runs and tables
  [self clearSegments];
  [self buildSegmentsFromNode:rootWrapper styleConfig:styleConfig customTags:customTags];
  [self emitContentSizeIfNeeded];
}

- (void)clearSegments {
  for (MarkdownSpoilerOverlay *overlay in _spoilerOverlays) {
    [overlay removeAllOverlays];
  }
  [_spoilerOverlays removeAllObjects];

  for (UIView *view in _stackView.arrangedSubviews) {
    [_stackView removeArrangedSubview:view];
    [view removeFromSuperview];
  }
}

- (void)buildSegmentsFromNode:(ASTNodeWrapper *)root
                  styleConfig:(StyleConfig *)styleConfig
                   customTags:(NSArray<NSString *> *)customTags {
  // Walk top-level children of the document. Group consecutive non-table
  // nodes into text segments; table nodes become table segments.
  NSMutableArray<ASTNodeWrapper *> *textNodes = [NSMutableArray new];

  for (ASTNodeWrapper *child in root.children) {
    if (child.nodeType == MDNodeTypeTable) {
      // Flush accumulated text nodes
      if (textNodes.count > 0) {
        [self addTextSegment:textNodes styleConfig:styleConfig customTags:customTags];
        textNodes = [NSMutableArray new];
      }
      // Add table segment
      [self addTableSegment:child styleConfig:styleConfig];
    } else {
      [textNodes addObject:child];
    }
  }

  // Flush remaining text nodes
  if (textNodes.count > 0) {
    [self addTextSegment:textNodes styleConfig:styleConfig customTags:customTags];
  }
}

- (void)addTextSegment:(NSArray<ASTNodeWrapper *> *)nodes
           styleConfig:(StyleConfig *)styleConfig
            customTags:(NSArray<NSString *> *)customTags {
  RenderContext *context = [[RenderContext alloc] init];
  context.styleConfig = styleConfig;
  context.customTags = [NSSet setWithArray:customTags];

  NSMutableAttributedString *output = [[NSMutableAttributedString alloc] init];
  for (ASTNodeWrapper *node in nodes) {
    id<NodeRenderer> renderer = [RendererFactory rendererForNode:node];
    if (renderer) {
      [renderer renderNode:node into:output context:context];
    }
  }

  // Trim trailing newline
  if (output.length > 0) {
    unichar lastChar = [output.string characterAtIndex:output.length - 1];
    if (lastChar == '\n') {
      [output deleteCharactersInRange:NSMakeRange(output.length - 1, 1)];
    }
  }

  if (output.length == 0) return;

  UITextView *textView = [[UITextView alloc] init];
  textView.attributedText = output;
  textView.editable = NO;
  textView.scrollEnabled = NO;
  textView.textContainerInset = UIEdgeInsetsZero;
  textView.textContainer.lineFragmentPadding = 0;
  textView.backgroundColor = [UIColor clearColor];
  textView.dataDetectorTypes = UIDataDetectorTypeNone;
  textView.delegate = self;

  // Size to fit content
  CGFloat width = self.bounds.size.width > 0
      ? self.bounds.size.width
      : UIScreen.mainScreen.bounds.size.width;
  CGSize size = [textView sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];
  textView.frame = CGRectMake(0, 0, width, size.height);

  // Set intrinsic height constraint
  [textView.heightAnchor constraintEqualToConstant:size.height].active = YES;

  [_stackView addArrangedSubview:textView];

  // Add spoiler overlays after the text view is laid out
  // Force layout so layoutManager has valid glyph positions
  [textView layoutIfNeeded];

  MarkdownSpoilerOverlay *spoilerOverlay =
      [[MarkdownSpoilerOverlay alloc] initWithTextView:textView];

  MarkdownElementStyle *spoilerStyle = styleConfig.spoiler;
  if (spoilerStyle.overlayColor) {
    spoilerOverlay.overlayColor = spoilerStyle.overlayColor;
  }

  [spoilerOverlay updateOverlays];
  [_spoilerOverlays addObject:spoilerOverlay];
}

- (void)addTableSegment:(ASTNodeWrapper *)tableNode
            styleConfig:(StyleConfig *)styleConfig {
  CGFloat width = self.bounds.size.width > 0
      ? self.bounds.size.width
      : UIScreen.mainScreen.bounds.size.width;

  MarkdownTableView *tableView =
      [[MarkdownTableView alloc] initWithTableNode:tableNode
                                       styleConfig:styleConfig
                                          maxWidth:width];

  tableView.frame = CGRectMake(0, 0, width, tableView.tableHeight);
  [tableView.heightAnchor constraintEqualToConstant:tableView.tableHeight].active = YES;

  [_stackView addArrangedSubview:tableView];
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
