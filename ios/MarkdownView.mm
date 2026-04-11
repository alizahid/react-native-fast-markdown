#import "MarkdownView.h"

#import <React/RCTConversions.h>
#import <React/RCTFabricComponentsPlugins.h>
#import <react/renderer/components/MarkdownViewSpec/ComponentDescriptors.h>
#import <react/renderer/components/MarkdownViewSpec/EventEmitters.h>
#import <react/renderer/components/MarkdownViewSpec/Props.h>

#import "ASTNodeWrapper.h"
#import "MarkdownBlockView.h"
#import "MarkdownParser.hpp"
#import "MarkdownSpoilerOverlay.h"
#import "MarkdownTableView.h"
#import "RenderContext.h"
#import "RendererFactory.h"
#import "StyleConfig.h"

using namespace facebook::react;

@interface MarkdownView () <UITextViewDelegate>
@end

@implementation MarkdownView {
  MarkdownBlockView *_baseContainer;
  UIStackView *_stackView;
  NSString *_currentMarkdown;
  NSString *_currentStyleJSON;
  NSArray<NSString *> *_customTags;
  StyleConfig *_styleConfig;

  BOOL _pendingSizeEmit;
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

    _stackView = [[UIStackView alloc] initWithFrame:CGRectZero];
    _stackView.axis = UILayoutConstraintAxisVertical;
    _stackView.alignment = UIStackViewAlignmentFill;
    _stackView.spacing = 0;
    _baseContainer.contentView = _stackView;

    _spoilerOverlays = [NSMutableArray new];
  }
  return self;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  _baseContainer.frame = self.bounds;

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
  if (_stackView.arrangedSubviews.count == 0) return;
  if (!_eventEmitter) {
    _pendingSizeEmit = YES;
    return;
  }

  CGFloat width = self.bounds.size.width > 0
      ? self.bounds.size.width
      : UIScreen.mainScreen.bounds.size.width;

  CGSize size = [_baseContainer sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];

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
    [self addSegmentForNode:child styleConfig:styleConfig customTags:customTags];
  }

  [self emitContentSizeIfNeeded];
}

- (void)clearSegments {
  for (MarkdownSpoilerOverlay *overlay in _spoilerOverlays) {
    [overlay removeAllOverlays];
  }
  [_spoilerOverlays removeAllObjects];

  for (UIView *view in [_stackView.arrangedSubviews copy]) {
    [_stackView removeArrangedSubview:view];
    [view removeFromSuperview];
  }
}

- (void)addSegmentForNode:(ASTNodeWrapper *)node
              styleConfig:(StyleConfig *)styleConfig
               customTags:(NSArray<NSString *> *)customTags {
  MDNodeType type = node.nodeType;

  if (type == MDNodeTypeTable) {
    [self addTableSegment:node styleConfig:styleConfig];
  } else if (type == MDNodeTypeThematicBreak) {
    [self addThematicBreakSegment:styleConfig];
  } else if (type == MDNodeTypeList) {
    [self addListSegment:node styleConfig:styleConfig customTags:customTags];
  } else {
    [self addTextBlockSegment:node
                  styleConfig:styleConfig
                   customTags:customTags];
  }
}

- (void)addTextBlockSegment:(ASTNodeWrapper *)node
                styleConfig:(StyleConfig *)styleConfig
                 customTags:(NSArray<NSString *> *)customTags {
  // Find the style key for this block node
  MarkdownElementStyle *blockStyle = [self blockStyleForNode:node styleConfig:styleConfig];

  // Render the node's content to an attributed string
  NSAttributedString *content = [self renderNodeToAttributedString:node
                                                       styleConfig:styleConfig
                                                        customTags:customTags];

  if (content.length == 0) return;

  // Wrap in a block view + text view
  MarkdownBlockView *blockView = [[MarkdownBlockView alloc] initWithStyle:blockStyle];

  UITextView *textView = [self makeTextViewWithAttributedText:content];
  blockView.contentView = textView;

  [_stackView addArrangedSubview:blockView];

  // Spoiler overlays for this text view
  [self attachSpoilerOverlayToTextView:textView styleConfig:styleConfig];
}

- (void)addListSegment:(ASTNodeWrapper *)node
           styleConfig:(StyleConfig *)styleConfig
            customTags:(NSArray<NSString *> *)customTags {
  MarkdownElementStyle *listStyle = styleConfig.list;
  MarkdownBlockView *listContainer =
      [[MarkdownBlockView alloc] initWithStyle:listStyle];

  UIStackView *itemStack = [[UIStackView alloc] initWithFrame:CGRectZero];
  itemStack.axis = UILayoutConstraintAxisVertical;
  itemStack.alignment = UIStackViewAlignmentFill;
  itemStack.spacing = listStyle.gap;
  listContainer.contentView = itemStack;

  MarkdownElementStyle *itemStyle = styleConfig.listItem;

  NSInteger orderedIndex = node.listStart > 0 ? node.listStart : 1;
  for (ASTNodeWrapper *child in node.children) {
    if (child.nodeType != MDNodeTypeListItem) continue;

    MarkdownBlockView *itemView =
        [[MarkdownBlockView alloc] initWithStyle:itemStyle];

    NSAttributedString *content =
        [self renderListItemContent:child
                      orderedIndex:orderedIndex
                       styleConfig:styleConfig
                        customTags:customTags];

    if (child.isOrderedList) orderedIndex++;

    UITextView *textView = [self makeTextViewWithAttributedText:content];
    itemView.contentView = textView;

    [itemStack addArrangedSubview:itemView];
    [self attachSpoilerOverlayToTextView:textView styleConfig:styleConfig];
  }

  [_stackView addArrangedSubview:listContainer];
}

- (void)addTableSegment:(ASTNodeWrapper *)tableNode
            styleConfig:(StyleConfig *)styleConfig {
  CGFloat width = self.bounds.size.width > 0
      ? self.bounds.size.width
      : UIScreen.mainScreen.bounds.size.width;

  // Account for base container's padding
  UIEdgeInsets basePadding = [_styleConfig.base resolvedPaddingInsets];
  width -= basePadding.left + basePadding.right;

  MarkdownTableView *tableView =
      [[MarkdownTableView alloc] initWithTableNode:tableNode
                                       styleConfig:styleConfig
                                          maxWidth:width];

  MarkdownBlockView *wrapper =
      [[MarkdownBlockView alloc] initWithStyle:styleConfig.table];
  wrapper.contentView = tableView;

  [_stackView addArrangedSubview:wrapper];
}

- (void)addThematicBreakSegment:(StyleConfig *)styleConfig {
  MarkdownBlockView *hrView =
      [[MarkdownBlockView alloc] initWithStyle:styleConfig.thematicBreak];
  [_stackView addArrangedSubview:hrView];
}

#pragma mark - Content rendering

- (NSAttributedString *)renderNodeToAttributedString:(ASTNodeWrapper *)node
                                         styleConfig:(StyleConfig *)styleConfig
                                          customTags:(NSArray<NSString *> *)customTags {
  RenderContext *context = [[RenderContext alloc] init];
  context.styleConfig = styleConfig;
  context.customTags = [NSSet setWithArray:customTags];

  NSMutableAttributedString *output = [[NSMutableAttributedString alloc] init];

  id<NodeRenderer> renderer = [RendererFactory rendererForNode:node];
  if (renderer) {
    [renderer renderNode:node into:output context:context];
  }

  // Trim trailing newlines — block separators are handled by stack spacing
  while (output.length > 0) {
    unichar last = [output.string characterAtIndex:output.length - 1];
    if (last == '\n') {
      [output deleteCharactersInRange:NSMakeRange(output.length - 1, 1)];
    } else {
      break;
    }
  }

  return [output copy];
}

- (NSAttributedString *)renderListItemContent:(ASTNodeWrapper *)item
                                 orderedIndex:(NSInteger)orderedIndex
                                  styleConfig:(StyleConfig *)styleConfig
                                   customTags:(NSArray<NSString *> *)customTags {
  RenderContext *context = [[RenderContext alloc] init];
  context.styleConfig = styleConfig;
  context.customTags = [NSSet setWithArray:customTags];
  context.orderedListIndex = orderedIndex;
  context.listDepth = 1;

  NSMutableAttributedString *output = [[NSMutableAttributedString alloc] init];

  id<NodeRenderer> renderer = [RendererFactory rendererForNode:item];
  if (renderer) {
    [renderer renderNode:item into:output context:context];
  }

  // Trim trailing newlines
  while (output.length > 0) {
    unichar last = [output.string characterAtIndex:output.length - 1];
    if (last == '\n') {
      [output deleteCharactersInRange:NSMakeRange(output.length - 1, 1)];
    } else {
      break;
    }
  }

  return [output copy];
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
  UITextView *textView = [[UITextView alloc] init];
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
  [textView layoutIfNeeded];

  MarkdownSpoilerOverlay *spoilerOverlay =
      [[MarkdownSpoilerOverlay alloc] initWithTextView:textView];

  MarkdownElementStyle *spoilerStyle = styleConfig.spoiler;
  if (spoilerStyle.backgroundColor) {
    spoilerOverlay.overlayColor = spoilerStyle.backgroundColor;
  }

  [spoilerOverlay updateOverlays];
  [_spoilerOverlays addObject:spoilerOverlay];
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
