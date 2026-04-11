#import "MarkdownView.h"

#import <React/RCTConversions.h>
#import <React/RCTFabricComponentsPlugins.h>
#import <react/renderer/components/MarkdownViewSpec/EventEmitters.h>
#import <react/renderer/components/MarkdownViewSpec/Props.h>

#import "ASTNodeWrapper.h"
#import "MarkdownBlockView.h"
#import "MarkdownInternalTextView.h"
#import "MarkdownParser.hpp"
#import "MarkdownSegmentStackView.h"
#import "MarkdownSpoilerOverlay.h"
#import "MarkdownTableView.h"
#import "MarkdownViewComponentDescriptor.h"
#import "RenderContext.h"
#import "RendererFactory.h"
#import "StyleAttributes.h"
#import "StyleConfig.h"

using namespace facebook::react;

@interface MarkdownView () <UITextViewDelegate>
@end

@implementation MarkdownView {
  MarkdownBlockView *_baseContainer;
  MarkdownSegmentStackView *_stackView;
  NSString *_currentMarkdown;
  NSString *_currentStyleJSON;
  NSArray<NSString *> *_customTags;
  StyleConfig *_styleConfig;

  NSMutableArray<MarkdownSpoilerOverlay *> *_spoilerOverlays;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<MarkdownViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _baseContainer = [[MarkdownBlockView alloc] initWithStyle:nil];
    [self addSubview:_baseContainer];

    _stackView = [[MarkdownSegmentStackView alloc] initWithFrame:CGRectZero];
    _stackView.spacing = 0;
    _baseContainer.contentView = _stackView;

    _spoilerOverlays = [NSMutableArray new];
  }
  return self;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  _baseContainer.frame = self.bounds;
}

- (void)updateProps:(const Props::Shared &)props
           oldProps:(const Props::Shared &)oldProps {
  const auto &newViewProps =
      *std::static_pointer_cast<const MarkdownViewProps>(props);

  NSString *markdown =
      [NSString stringWithUTF8String:newViewProps.markdown.c_str()];
  NSString *styleJSON = newViewProps.styles.empty()
                            ? @""
                            : [NSString stringWithUTF8String:newViewProps.styles.c_str()];

  NSMutableArray<NSString *> *customTags = [NSMutableArray new];
  for (const auto &tag : newViewProps.customTags) {
    [customTags addObject:[NSString stringWithUTF8String:tag.c_str()]];
  }

  BOOL markdownChanged = ![markdown isEqualToString:_currentMarkdown ?: @""];
  BOOL styleChanged = ![styleJSON isEqualToString:_currentStyleJSON ?: @""];

  _currentMarkdown = markdown;
  _currentStyleJSON = styleJSON;
  _customTags = customTags;

  if (styleChanged) {
    _styleConfig = [StyleConfig fromJSON:styleJSON];

    // Apply base style to the outer container
    _baseContainer.style = _styleConfig.base;

    // Stack spacing = base.gap
    _stackView.spacing = _styleConfig.base.gap;
  }

  if (markdownChanged || styleChanged) {
    [self renderMarkdown];
  }

  [super updateProps:props oldProps:oldProps];
}

#pragma mark - Rendering

- (void)renderMarkdown {
  NSString *markdown = _currentMarkdown;
  [self clearSegments];

  if (!markdown || markdown.length == 0) return;

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

  // Build a segment for each top-level child
  for (ASTNodeWrapper *child in rootWrapper.children) {
    [self addSegmentForNode:child
                    toStack:_stackView
                styleConfig:styleConfig
                 customTags:customTags
             inheritedAttrs:nil];
  }
}

- (void)clearSegments {
  for (MarkdownSpoilerOverlay *overlay in _spoilerOverlays) {
    [overlay removeAllOverlays];
  }
  [_spoilerOverlays removeAllObjects];

  [_stackView removeAllArrangedSubviews];
}

- (void)addSegmentForNode:(ASTNodeWrapper *)node
                  toStack:(MarkdownSegmentStackView *)stack
              styleConfig:(StyleConfig *)styleConfig
               customTags:(NSArray<NSString *> *)customTags
           inheritedAttrs:(NSDictionary *)inheritedAttrs {
  MDNodeType type = node.nodeType;

  if (type == MDNodeTypeTable) {
    [self addTableSegment:node toStack:stack styleConfig:styleConfig];
  } else if (type == MDNodeTypeThematicBreak) {
    [self addThematicBreakSegment:styleConfig toStack:stack];
  } else if (type == MDNodeTypeList) {
    [self addListSegment:node
                 toStack:stack
             styleConfig:styleConfig
              customTags:customTags
          inheritedAttrs:inheritedAttrs];
  } else if (type == MDNodeTypeBlockquote) {
    [self addBlockquoteSegment:node
                       toStack:stack
                   styleConfig:styleConfig
                    customTags:customTags
                inheritedAttrs:inheritedAttrs];
  } else {
    [self addTextBlockSegment:node
                      toStack:stack
                  styleConfig:styleConfig
                   customTags:customTags
               inheritedAttrs:inheritedAttrs];
  }
}

- (void)addTextBlockSegment:(ASTNodeWrapper *)node
                    toStack:(MarkdownSegmentStackView *)stack
                styleConfig:(StyleConfig *)styleConfig
                 customTags:(NSArray<NSString *> *)customTags
             inheritedAttrs:(NSDictionary *)inheritedAttrs {
  // Find the style key for this block node
  MarkdownElementStyle *blockStyle = [self blockStyleForNode:node styleConfig:styleConfig];

  // Render the node's content to an attributed string
  NSAttributedString *content =
      [RenderContext renderNodeToAttributedString:node
                                      styleConfig:styleConfig
                                       customTags:customTags
                                   inheritedAttrs:inheritedAttrs];

  if (content.length == 0) return;

  // Wrap in a block view + text view
  MarkdownBlockView *blockView = [[MarkdownBlockView alloc] initWithStyle:blockStyle];

  UITextView *textView = [self makeTextViewWithAttributedText:content];
  blockView.contentView = textView;

  [stack addArrangedSubview:blockView];

  // Spoiler overlays for this text view
  [self attachSpoilerOverlayToTextView:textView styleConfig:styleConfig];
}

- (void)addListSegment:(ASTNodeWrapper *)node
               toStack:(MarkdownSegmentStackView *)stack
           styleConfig:(StyleConfig *)styleConfig
            customTags:(NSArray<NSString *> *)customTags
        inheritedAttrs:(NSDictionary *)inheritedAttrs {
  MarkdownElementStyle *listStyle = styleConfig.list;
  MarkdownBlockView *listContainer =
      [[MarkdownBlockView alloc] initWithStyle:listStyle];

  MarkdownSegmentStackView *itemStack =
      [[MarkdownSegmentStackView alloc] initWithFrame:CGRectZero];
  itemStack.spacing = listStyle.gap;
  listContainer.contentView = itemStack;

  MarkdownElementStyle *itemStyle = styleConfig.listItem;

  BOOL isOrdered = node.isOrderedList;
  NSInteger orderedIndex = isOrdered && node.listStart > 0 ? node.listStart : 1;

  // Digit count of the largest marker in this list — used to left-pad
  // shorter markers so the periods line up.
  NSInteger maxMarkerDigits = 0;
  if (isOrdered) {
    NSInteger itemCount = 0;
    for (ASTNodeWrapper *child in node.children) {
      if (child.nodeType == MDNodeTypeListItem) itemCount++;
    }
    NSInteger lastNumber = MAX(1, orderedIndex + itemCount - 1);
    maxMarkerDigits = 1;
    while (lastNumber >= 10) {
      maxMarkerDigits++;
      lastNumber /= 10;
    }
  }

  for (ASTNodeWrapper *child in node.children) {
    if (child.nodeType != MDNodeTypeListItem) continue;

    MarkdownBlockView *itemView =
        [[MarkdownBlockView alloc] initWithStyle:itemStyle];

    NSAttributedString *content =
        [RenderContext renderListItemContent:child
                                   isOrdered:isOrdered
                                orderedIndex:orderedIndex
                             maxMarkerDigits:maxMarkerDigits
                                 styleConfig:styleConfig
                                  customTags:customTags
                              inheritedAttrs:inheritedAttrs];

    if (isOrdered) orderedIndex++;

    UITextView *textView = [self makeTextViewWithAttributedText:content];
    itemView.contentView = textView;

    [itemStack addArrangedSubview:itemView];
    [self attachSpoilerOverlayToTextView:textView styleConfig:styleConfig];
  }

  [stack addArrangedSubview:listContainer];
}

- (void)addBlockquoteSegment:(ASTNodeWrapper *)node
                     toStack:(MarkdownSegmentStackView *)stack
                 styleConfig:(StyleConfig *)styleConfig
                  customTags:(NSArray<NSString *> *)customTags
              inheritedAttrs:(NSDictionary *)inheritedAttrs {
  MarkdownElementStyle *blockquoteStyle = styleConfig.blockquote;

  MarkdownBlockView *container =
      [[MarkdownBlockView alloc] initWithStyle:blockquoteStyle];

  MarkdownSegmentStackView *inner =
      [[MarkdownSegmentStackView alloc] initWithFrame:CGRectZero];
  inner.spacing = blockquoteStyle.gap;
  container.contentView = inner;

  // Compose the attrs children inherit: start from our own inherited
  // attrs (or the root base if we're top-level), then overlay the
  // blockquote's text style so things like fontStyle / color /
  // fontFamily cascade through into paragraphs inside — and into any
  // nested blockquotes' children, since they'll layer on top of this.
  NSMutableDictionary *childAttrs =
      [(inheritedAttrs
            ?: [RenderContext baseAttributesFromStyleConfig:styleConfig])
          mutableCopy];
  [StyleAttributes applyStyle:blockquoteStyle toAttrs:childAttrs];
  NSDictionary *childAttrsFrozen = [childAttrs copy];

  for (ASTNodeWrapper *child in node.children) {
    [self addSegmentForNode:child
                    toStack:inner
                styleConfig:styleConfig
                 customTags:customTags
             inheritedAttrs:childAttrsFrozen];
  }

  [stack addArrangedSubview:container];
}

- (void)addTableSegment:(ASTNodeWrapper *)tableNode
                toStack:(MarkdownSegmentStackView *)stack
            styleConfig:(StyleConfig *)styleConfig {
  CGFloat width = self.bounds.size.width > 0
      ? self.bounds.size.width
      : UIScreen.mainScreen.bounds.size.width;

  // Account for the base container's margin/padding/borders AND the
  // table wrapper's margin/padding/borders so this path computes the
  // same inner width MarkdownMeasurer used during shadow-thread
  // measurement. If they drift the view-built table will be a
  // different size than Yoga reserved and content will overflow or
  // leave empty space.
  UIEdgeInsets baseMargin = [_styleConfig.base resolvedMarginInsets];
  UIEdgeInsets basePadding = [_styleConfig.base resolvedPaddingInsets];
  UIEdgeInsets baseBorders = [_styleConfig.base resolvedBorderWidths];
  width -= baseMargin.left + baseMargin.right + basePadding.left +
           basePadding.right + baseBorders.left + baseBorders.right;

  MarkdownElementStyle *tableStyle = styleConfig.table;
  UIEdgeInsets wrapperMargin = [tableStyle resolvedMarginInsets];
  UIEdgeInsets wrapperPadding = [tableStyle resolvedPaddingInsets];
  UIEdgeInsets wrapperBorders = [tableStyle resolvedBorderWidths];
  CGFloat tableInnerWidth = width - wrapperMargin.left - wrapperMargin.right -
                            wrapperPadding.left - wrapperPadding.right -
                            wrapperBorders.left - wrapperBorders.right;

  MarkdownTableView *tableView =
      [[MarkdownTableView alloc] initWithTableNode:tableNode
                                       styleConfig:styleConfig
                                          maxWidth:tableInnerWidth];

  MarkdownBlockView *wrapper =
      [[MarkdownBlockView alloc] initWithStyle:tableStyle];
  wrapper.contentView = tableView;

  [stack addArrangedSubview:wrapper];
}

- (void)addThematicBreakSegment:(StyleConfig *)styleConfig
                        toStack:(MarkdownSegmentStackView *)stack {
  MarkdownBlockView *hrView =
      [[MarkdownBlockView alloc] initWithStyle:styleConfig.thematicBreak];
  [stack addArrangedSubview:hrView];
}

#pragma mark - Helpers

- (MarkdownElementStyle *)blockStyleForNode:(ASTNodeWrapper *)node
                                styleConfig:(StyleConfig *)styleConfig {
  switch (node.nodeType) {
    case MDNodeTypeParagraph:
      return styleConfig.paragraph;
    case MDNodeTypeHeading:
      return [styleConfig styleForHeadingLevel:node.headingLevel];
    case MDNodeTypeCodeBlock:
      return styleConfig.codeBlock;
    case MDNodeTypeBlockquote:
      return styleConfig.blockquote;
    default:
      return nil;
  }
}

- (UITextView *)makeTextViewWithAttributedText:(NSAttributedString *)text {
  MarkdownInternalTextView *textView = [[MarkdownInternalTextView alloc] init];
  // Empty linkTextAttributes tells UITextView not to override the
  // attributed string's own color / underline / etc. on ranges that
  // have NSLinkAttributeName set. Otherwise it forces its tint color
  // and ignores whatever our LinkRenderer put on the string.
  textView.linkTextAttributes = @{};
  textView.attributedText = text;
  textView.editable = NO;
  textView.scrollEnabled = NO;
  textView.textContainerInset = UIEdgeInsetsZero;
  textView.textContainer.lineFragmentPadding = 0;
  textView.backgroundColor = [UIColor clearColor];
  textView.dataDetectorTypes = UIDataDetectorTypeNone;
  textView.delegate = self;
  return textView;
}

- (void)attachSpoilerOverlayToTextView:(UITextView *)textView
                           styleConfig:(StyleConfig *)styleConfig {
  MarkdownSpoilerOverlay *spoilerOverlay =
      [[MarkdownSpoilerOverlay alloc] initWithTextView:textView];

  MarkdownElementStyle *spoilerStyle = styleConfig.spoiler;
  if (spoilerStyle.backgroundColor) {
    spoilerOverlay.overlayColor = spoilerStyle.backgroundColor;
  }

  // Rebuild the overlay rects every time the text view lays out —
  // they depend on the computed line fragments, which only become
  // accurate after the view has a real width. Without this the
  // overlay is sized against the zero bounds the text view has at
  // construction time and ends up as one giant rect on the first
  // line.
  if ([textView isKindOfClass:[MarkdownInternalTextView class]]) {
    __weak MarkdownSpoilerOverlay *weakOverlay = spoilerOverlay;
    ((MarkdownInternalTextView *)textView).onLayoutSubviews = ^{
      [weakOverlay updateOverlays];
    };
  }

  [_spoilerOverlays addObject:spoilerOverlay];
}

#pragma mark - UITextViewDelegate

- (BOOL)textView:(UITextView *)textView
    shouldInteractWithURL:(NSURL *)URL
                  inRange:(NSRange)characterRange
              interaction:(UITextItemInteraction)interaction {
  NSString *scheme = URL.scheme.lowercaseString;
  BOOL isHttp = [scheme isEqualToString:@"http"] ||
                [scheme isEqualToString:@"https"];

  if (interaction == UITextItemInteractionInvokeDefaultAction) {
    // Tap — emit onLinkPress so JS can handle (open in-app, log,
    // override, etc.). Always return NO so UITextView doesn't also
    // open the URL in Safari behind our back.
    if (_eventEmitter) {
      const auto &eventEmitter =
          static_cast<const MarkdownViewEventEmitter &>(*_eventEmitter);
      eventEmitter.onLinkPress({
          .url = std::string([[URL absoluteString] UTF8String]),
          .title = std::string(""),
      });
    }
    return NO;
  }

  if (interaction == UITextItemInteractionPresentActions) {
    // Long-press — for http(s) URLs return YES so UITextView shows
    // the native iOS link context menu (the popover with a rendered
    // webpage preview and Open / Copy Link / Add to Reading List /
    // Share). For custom schemes (deeplinks, mailto:, tel:, etc.)
    // fall back to firing onLinkLongPress so JS can decide.
    if (isHttp) {
      return YES;
    }

    if (_eventEmitter) {
      const auto &eventEmitter =
          static_cast<const MarkdownViewEventEmitter &>(*_eventEmitter);
      eventEmitter.onLinkLongPress({
          .url = std::string([[URL absoluteString] UTF8String]),
          .title = std::string(""),
      });
    }
    return NO;
  }

  return NO;
}

@end

Class<RCTComponentViewProtocol> MarkdownViewCls(void) {
  return MarkdownView.class;
}
