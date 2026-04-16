#import "MarkdownView.h"

#import <React/RCTConversions.h>
#import <React/RCTFabricComponentsPlugins.h>
#import <react/renderer/components/MarkdownViewSpec/EventEmitters.h>
#import <react/renderer/components/MarkdownViewSpec/Props.h>
#import <react/renderer/core/ConcreteState.h>

#include <atomic>

#import <UIKit/UIGestureRecognizerSubclass.h>

#import "ASTNodeWrapper.h"
#import "CustomTagRenderer.h"
#import "MarkdownBlockView.h"
#import "MarkdownImageSizeCache.h"
#import "MarkdownImageView.h"
#import "MarkdownInternalTextView.h"
#import "MarkdownPressableOverlayView.h"
#import "MarkdownMeasurer.h"
#import "MarkdownMentionOverlay.h"
#import "MarkdownParser.hpp"
#import "MarkdownSegmentStackView.h"
#import "MarkdownSpoilerOverlay.h"
#import "MarkdownTableView.h"
#import "MarkdownViewComponentDescriptor.h"
#import "MarkdownViewState.h"
#import "RenderContext.h"
#import "RendererFactory.h"
#import "StyleAttributes.h"
#import "StyleConfig.h"

// Default height reserved for a block image before the URL has
// finished loading. If the user sets styleConfig.image.height this
// is overridden per segment.
static const CGFloat kDefaultImageHeight = 200.0;

using namespace facebook::react;

#pragma mark - Touch-blocking gesture recognizer

/// Prevents a parent Pressable from firing when the touch lands on an
/// interactive native element (overlay or link). Scrollable tables are
/// handled separately by MarkdownTablePanRecognizer.
///
/// Only receives touches that MarkdownView.hitTest routed to a native
/// child — non-interactive touches return nil from hitTest and never
/// reach this recognizer.
@interface MarkdownTouchBlockingRecognizer : UIGestureRecognizer
@end

@implementation MarkdownTouchBlockingRecognizer

- (void)touchesBegan:(NSSet<UITouch *> *)touches
            withEvent:(UIEvent *)event {
  [super touchesBegan:touches withEvent:event];

  UIView *hitView = touches.anyObject.view;

  if ([hitView isKindOfClass:[UIControl class]] ||
      [hitView isKindOfClass:[UITextView class]]) {
    // Overlay (mention, spoiler, image) or link — block parent.
    self.state = UIGestureRecognizerStateRecognized;
  } else {
    // Everything else (including scrollable tables routed to self)
    // — let parent Pressable handle. Table scroll blocking is done
    // by the separate MarkdownTablePanRecognizer.
    self.state = UIGestureRecognizerStateFailed;
  }
}

#pragma mark - Failure-requirement wiring

- (BOOL)shouldBeRequiredToFailByGestureRecognizer:
    (UIGestureRecognizer *)other {
  UIView *otherView = other.view;
  if (!otherView) return NO;

  // Don't block recognizers on our own view tree.
  if ([otherView isDescendantOfView:self.view]) return NO;

  // Don't block pan recognizers — parent scroll views need them.
  if ([other isKindOfClass:[UIPanGestureRecognizer class]]) return NO;

  // Block everything else on ancestor views (RCTSurfaceTouchHandler,
  // RNGH tap/press handlers, etc).
  return YES;
}

- (BOOL)canPreventGestureRecognizer:
    (UIGestureRecognizer *)preventedGR {
  return NO;
}

- (BOOL)canBePreventedByGestureRecognizer:
    (UIGestureRecognizer *)preventingGR {
  return NO;
}

@end

#pragma mark - Table-scroll pan recognizer

/// UIPanGestureRecognizer that drives horizontal scrolling for
/// scrollable MarkdownTableViews. Installed on MarkdownView itself
/// (not on the table) so that hitTest can return self for table areas
/// — letting the blocking recognizer fail and allowing parent
/// Pressable taps to work.
///
/// shouldBeRequiredToFailByGestureRecognizer: makes ancestor touch
/// handlers (RCTSurfaceTouchHandler, RNGH) wait for this recognizer.
/// gestureRecognizerShouldBegin: (via delegate) ensures it only
/// begins for horizontal pans over scrollable tables. Result:
///   • Pan → this recognizer begins → ancestors fail → no Pressable
///   • Tap → this recognizer never begins → fails → Pressable fires
@interface MarkdownTablePanRecognizer : UIPanGestureRecognizer
@end

@implementation MarkdownTablePanRecognizer

- (BOOL)shouldBeRequiredToFailByGestureRecognizer:
    (UIGestureRecognizer *)other {
  UIView *otherView = other.view;
  if (!otherView) return NO;
  if ([otherView isDescendantOfView:self.view]) return NO;
  if ([other isKindOfClass:[UIPanGestureRecognizer class]]) return NO;
  return YES;
}

- (BOOL)canPreventGestureRecognizer:
    (UIGestureRecognizer *)preventedGR {
  return NO;
}

- (BOOL)canBePreventedByGestureRecognizer:
    (UIGestureRecognizer *)preventingGR {
  return NO;
}

@end

#pragma mark - MarkdownView

@interface MarkdownView () <UITextViewDelegate, UIGestureRecognizerDelegate>
@end

@implementation MarkdownView {
  MarkdownBlockView *_baseContainer;
  MarkdownSegmentStackView *_stackView;
  NSString *_currentMarkdown;
  NSString *_currentStyleJSON;
  NSArray<NSString *> *_customTags;
  StyleConfig *_styleConfig;

  // URL → NSValue(CGSize) of dimensions supplied via the `images`
  // prop. Authoritative — passed to each MarkdownImageView at
  // construction time so its sizeThatFits and layoutSubviews
  // reserve the right rect before the actual bytes arrive.
  NSDictionary<NSString *, NSValue *> *_propImageSizes;

  NSMutableArray<MarkdownSpoilerOverlay *> *_spoilerOverlays;
  NSMutableArray<MarkdownMentionOverlay *> *_mentionOverlays;

  MarkdownTablePanRecognizer *_tablePanGR;
  __weak MarkdownTableView *_panTargetTable;

  // Captured in updateState:oldState: so markNeedsRemeasure can
  // dispatch a new state update back to the shadow tree.
  MarkdownViewShadowNode::ConcreteState::Shared _markdownState;

  // Monotonically increasing token we stamp onto MarkdownViewState
  // every time we want Yoga to re-run measureContent. Each bump is
  // enough to make the state data compare as changed, which is the
  // only thing the reconciler cares about.
  std::atomic<int64_t> _measureRevision;
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
    _mentionOverlays = [NSMutableArray new];

    // Block parent Pressable when a touch lands on an interactive
    // native element. Non-interactive touches never reach this
    // recognizer because hitTest returns nil for them.
    MarkdownTouchBlockingRecognizer *blocker =
        [[MarkdownTouchBlockingRecognizer alloc] initWithTarget:nil
                                                         action:nil];
    blocker.cancelsTouchesInView = NO;
    blocker.delaysTouchesBegan = NO;
    blocker.delaysTouchesEnded = NO;
    [self addGestureRecognizer:blocker];

    // Horizontal-pan recognizer that drives scrollable table views.
    // Installed on MarkdownView (not on the table) so that hitTest
    // can return self for table areas, letting the blocking
    // recognizer fail and parent Pressable taps work.
    _tablePanGR =
        [[MarkdownTablePanRecognizer alloc] initWithTarget:self
                                                    action:@selector(handleTablePan:)];
    _tablePanGR.cancelsTouchesInView = NO;
    _tablePanGR.delegate = self;
    [self addGestureRecognizer:_tablePanGR];

    // Listen for async image loads so we can dirty the measurer
    // cache and force Yoga to re-call measureContent with the
    // newly-known natural sizes.
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(handleImageSizeCacheUpdate:)
               name:MarkdownImageSizeCacheDidUpdateNotification
             object:nil];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  _baseContainer.frame = self.bounds;
}

#pragma mark - Hit testing

/// Routes touches: interactive elements (overlays, links, scrollable
/// tables) are returned so native gesture handling works. Everything
/// else returns nil so the touch falls through to a parent Pressable.
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
  if (!self.userInteractionEnabled || self.hidden || self.alpha < 0.01) {
    return nil;
  }
  if (![self pointInside:point withEvent:event]) {
    return nil;
  }

  UIView *hitView = [super hitTest:point withEvent:event];
  if (!hitView || hitView == self) return nil;

  // 1. Overlay (mention, spoiler, image press) — interactive.
  if ([hitView isKindOfClass:[MarkdownPressableOverlayView class]]) {
    return hitView;
  }

  // 2. Text view (or an internal subview of one) — check for link.
  MarkdownInternalTextView *textView =
      [self markdownTextViewAncestorOf:hitView];
  if (textView) {
    CGPoint localPoint = [self convertPoint:point toView:textView];
    if ([self isPointOverLink:localPoint inTextView:textView]) {
      return textView;
    }
    return nil; // Plain text — pass through.
  }

  // 3. Scrollable table — return self (not the table) so the
  //    blocking recognizer fails (it only blocks UIControl /
  //    UITextView). The MarkdownTablePanRecognizer on self handles
  //    horizontal scrolling and blocks the parent Pressable only
  //    when actual movement is detected. Taps pass through.
  if ([self scrollableTableAncestorOf:hitView]) {
    return self;
  }

  // 4. Everything else (empty space, block containers, non-scrollable
  //    table cells) — pass through to parent Pressable.
  return nil;
}

/// Walks from `view` up to (but not including) self, looking for a
/// MarkdownInternalTextView ancestor.
- (nullable MarkdownInternalTextView *)markdownTextViewAncestorOf:
    (UIView *)view {
  UIView *v = view;
  while (v && v != self) {
    if ([v isKindOfClass:[MarkdownInternalTextView class]]) {
      return (MarkdownInternalTextView *)v;
    }
    v = v.superview;
  }
  return nil;
}

/// Walks from `view` up to (but not including) self, looking for a
/// scrollable MarkdownTableView ancestor.
- (nullable MarkdownTableView *)scrollableTableAncestorOf:
    (UIView *)view {
  UIView *v = view;
  while (v && v != self) {
    if ([v isKindOfClass:[MarkdownTableView class]]) {
      MarkdownTableView *table = (MarkdownTableView *)v;
      return table.scrollEnabled ? table : nil;
    }
    v = v.superview;
  }
  return nil;
}

/// Returns YES when `point` (in the text view's coordinate space)
/// lands on a character that carries NSLinkAttributeName.
- (BOOL)isPointOverLink:(CGPoint)point
             inTextView:(UITextView *)textView {
  NSLayoutManager *lm = textView.layoutManager;
  NSTextContainer *tc = textView.textContainer;
  NSTextStorage *storage = textView.textStorage;
  if (!lm || !tc || !storage || storage.length == 0) return NO;

  CGPoint textPoint = CGPointMake(
      point.x - textView.textContainerInset.left,
      point.y - textView.textContainerInset.top);

  CGRect textBounds = [lm usedRectForTextContainer:tc];
  if (!CGRectContainsPoint(textBounds, textPoint)) return NO;

  CGFloat fraction = 0;
  NSUInteger glyphIdx =
      [lm glyphIndexForPoint:textPoint
              inTextContainer:tc
  fractionOfDistanceThroughGlyph:&fraction];

  CGRect glyphRect =
      [lm boundingRectForGlyphRange:NSMakeRange(glyphIdx, 1)
                     inTextContainer:tc];
  if (!CGRectContainsPoint(glyphRect, textPoint)) return NO;

  NSUInteger charIdx = [lm characterIndexForGlyphAtIndex:glyphIdx];
  if (charIdx >= storage.length) return NO;

  return [storage attribute:NSLinkAttributeName
                    atIndex:charIdx
             effectiveRange:nil] != nil;
}

/// Like isPointOverLink: but returns the NSURL (or nil).
- (nullable NSURL *)linkURLAtPoint:(CGPoint)point
                        inTextView:(UITextView *)textView {
  NSLayoutManager *lm = textView.layoutManager;
  NSTextContainer *tc = textView.textContainer;
  NSTextStorage *storage = textView.textStorage;
  if (!lm || !tc || !storage || storage.length == 0) return nil;

  CGPoint textPoint = CGPointMake(
      point.x - textView.textContainerInset.left,
      point.y - textView.textContainerInset.top);

  CGRect textBounds = [lm usedRectForTextContainer:tc];
  if (!CGRectContainsPoint(textBounds, textPoint)) return nil;

  CGFloat fraction = 0;
  NSUInteger glyphIdx =
      [lm glyphIndexForPoint:textPoint
              inTextContainer:tc
  fractionOfDistanceThroughGlyph:&fraction];

  CGRect glyphRect =
      [lm boundingRectForGlyphRange:NSMakeRange(glyphIdx, 1)
                     inTextContainer:tc];
  if (!CGRectContainsPoint(glyphRect, textPoint)) return nil;

  NSUInteger charIdx = [lm characterIndexForGlyphAtIndex:glyphIdx];
  if (charIdx >= storage.length) return nil;

  id link = [storage attribute:NSLinkAttributeName
                       atIndex:charIdx
                effectiveRange:nil];
  if (!link) return nil;
  if ([link isKindOfClass:[NSURL class]]) return link;
  if ([link isKindOfClass:[NSString class]])
    return [NSURL URLWithString:link];
  return nil;
}

- (void)updateProps:(const Props::Shared &)props
           oldProps:(const Props::Shared &)oldProps {
  // Re-register the image-size notification after prepareForRecycle
  // removed the observer.
  if (!_currentMarkdown) {
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(handleImageSizeCacheUpdate:)
               name:MarkdownImageSizeCacheDidUpdateNotification
             object:nil];
  }

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

  // Build the per-view prop-image-sizes dict from the `images`
  // prop. Stored on the instance so addImageSegment can look up
  // a URL's authoritative dimensions and hand them to
  // MarkdownImageView at construction time. Rebuilt on every
  // updateProps: so live-edited dimensions (or URLs dropped from
  // the prop altogether) are reflected in the next render pass.
  NSMutableDictionary<NSString *, NSValue *> *propImageSizes =
      [NSMutableDictionary new];
  for (const auto &img : newViewProps.images) {
    if (img.url.empty()) continue;
    if (img.width <= 0 || img.height <= 0) continue;
    NSString *urlKey = [NSString stringWithUTF8String:img.url.c_str()];
    propImageSizes[urlKey] =
        [NSValue valueWithCGSize:CGSizeMake(img.width, img.height)];
  }

  BOOL markdownChanged = ![markdown isEqualToString:_currentMarkdown ?: @""];
  BOOL styleChanged = ![styleJSON isEqualToString:_currentStyleJSON ?: @""];
  BOOL imagesChanged =
      ![(_propImageSizes ?: @{}) isEqualToDictionary:propImageSizes];

  _currentMarkdown = markdown;
  _currentStyleJSON = styleJSON;
  _customTags = customTags;
  _propImageSizes = [propImageSizes copy];

  if (styleChanged) {
    _styleConfig = [StyleConfig fromJSON:styleJSON];

    // Apply base style to the outer container
    _baseContainer.style = _styleConfig.base;

    // Stack spacing = base.gap
    _stackView.spacing = !isnan(_styleConfig.base.gap) ? _styleConfig.base.gap : 0;
  }

  if (markdownChanged || styleChanged || imagesChanged) {
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

  // Built-in custom tags — always recognized so users don't have to
  // register them via the `customTags` prop.
  options.customTags.insert("UserMention");
  options.customTags.insert("ChannelMention");
  options.customTags.insert("Command");
  options.customTags.insert("Spoiler");
  options.customTags.insert("Superscript");

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

  for (MarkdownMentionOverlay *overlay in _mentionOverlays) {
    [overlay removeAllOverlays];
  }
  [_mentionOverlays removeAllObjects];

  // Nil out onLayoutSubviews callbacks before removing text views,
  // otherwise the blocks can fire on a detached view during recycling.
  for (UIView *subview in _stackView.subviews) {
    [self clearCallbacksRecursive:subview];
  }
  [_stackView removeAllArrangedSubviews];
}

- (void)clearCallbacksRecursive:(UIView *)view {
  if ([view isKindOfClass:[MarkdownInternalTextView class]]) {
    ((MarkdownInternalTextView *)view).onLayoutSubviews = nil;
  }
  for (UIView *child in view.subviews) {
    [self clearCallbacksRecursive:child];
  }
}

- (void)addSegmentForNode:(ASTNodeWrapper *)node
                  toStack:(MarkdownSegmentStackView *)stack
              styleConfig:(StyleConfig *)styleConfig
               customTags:(NSArray<NSString *> *)customTags
           inheritedAttrs:(NSDictionary *)inheritedAttrs {
  MDNodeType type = node.nodeType;

  // `![alt](url)` on its own line parses as Paragraph { Image } —
  // hand that to the dedicated image-segment path so we render it
  // as a real UIImageView with async loading instead of flattening
  // it through the attributed-string pipeline.
  ASTNodeWrapper *imageChild = [self imageOnlyParagraphChild:node];
  if (imageChild) {
    [self addImageSegment:imageChild
                  toStack:stack
              styleConfig:styleConfig];
    return;
  }

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

/// Returns the single Image child of a top-level paragraph whose
/// only non-whitespace content is an image. `![alt](url)` on its
/// own line is exactly this shape. Returns nil for anything else
/// (paragraphs with mixed inline content, paragraphs with multiple
/// images, non-paragraph nodes) — those fall through to the
/// regular text-block path where inline images stay as placeholders.
- (nullable ASTNodeWrapper *)imageOnlyParagraphChild:(ASTNodeWrapper *)node {
  if (node.nodeType != MDNodeTypeParagraph) return nil;

  ASTNodeWrapper *imageChild = nil;
  NSCharacterSet *whitespace =
      [NSCharacterSet whitespaceAndNewlineCharacterSet];
  for (ASTNodeWrapper *child in node.children) {
    if (child.nodeType == MDNodeTypeImage) {
      if (imageChild) return nil; // more than one image — punt
      imageChild = child;
    } else if (child.nodeType == MDNodeTypeText) {
      NSString *trimmed =
          [child.content stringByTrimmingCharactersInSet:whitespace];
      if (trimmed.length > 0) return nil; // real text next to image
    } else if (child.nodeType == MDNodeTypeSoftBreak ||
               child.nodeType == MDNodeTypeLineBreak) {
      // Soft / hard breaks are fine — they're just whitespace in
      // the source markdown.
      continue;
    } else {
      return nil; // some other inline element — render as text
    }
  }

  return imageChild;
}

- (void)addImageSegment:(ASTNodeWrapper *)imageNode
                toStack:(MarkdownSegmentStackView *)stack
            styleConfig:(StyleConfig *)styleConfig {
  MarkdownElementStyle *imageStyle = styleConfig.image;

  NSString *urlString = imageNode.imageSrc;
  NSURL *url = urlString.length > 0
                   ? [NSURL URLWithString:urlString]
                   : nil;

  CGFloat fallbackWidth = imageStyle.width;
  CGFloat fallbackHeight =
      imageStyle.height > 0 ? imageStyle.height : kDefaultImageHeight;

  // Look up the authoritative size for this URL from the props
  // we captured in updateProps:. CGSizeZero when the caller
  // didn't declare dimensions — MarkdownImageView falls back to
  // the discovered cache in that case.
  CGSize propSize = CGSizeZero;
  if (urlString.length > 0) {
    NSValue *propValue = _propImageSizes[urlString];
    if (propValue) propSize = [propValue CGSizeValue];
  }

  MarkdownBlockView *blockView =
      [[MarkdownBlockView alloc] initWithStyle:imageStyle];
  // Hug the image's natural width so the block sizes to the image
  // instead of stretching across the whole row. Everything in
  // imageStyle (bg, border, radius) then wraps the image tightly.
  blockView.huggingContent = YES;
  MarkdownImageView *imageView =
      [[MarkdownImageView alloc] initWithURL:url
                                    propSize:propSize
                                fallbackWidth:fallbackWidth
                               fallbackHeight:fallbackHeight
                                    maxWidth:imageStyle.maxWidth
                                   maxHeight:imageStyle.maxHeight
                                   objectFit:imageStyle.objectFit];

  __weak __typeof(self) weakSelf = self;
  imageView.onPress = ^(NSURL *pressedURL, CGSize size) {
    [weakSelf emitImagePressForURL:pressedURL size:size];
  };

  blockView.contentView = imageView;
  [stack addArrangedSubview:blockView];
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

  // If this top-level segment is itself a CustomTag node (e.g. a
  // block-level <Spoiler>…</Spoiler>), stamp every spoiler range in
  // the rendered string with MarkdownSpoilerIsBlockKey so the
  // overlay system draws a solid rectangle instead of a staircase
  // polygon that follows the text contour.
  if (node.nodeType == MDNodeTypeCustomTag) {
    NSMutableAttributedString *mut = [content mutableCopy];
    [mut enumerateAttribute:MarkdownSpoilerRangeKey
                    inRange:NSMakeRange(0, mut.length)
                    options:0
                 usingBlock:^(id value, NSRange range, BOOL *stop) {
      if (value) {
        [mut addAttribute:MarkdownSpoilerIsBlockKey
                    value:@YES
                    range:range];
      }
    }];
    content = [mut copy];
  }

  // Wrap in a block view + text view
  MarkdownBlockView *blockView = [[MarkdownBlockView alloc] initWithStyle:blockStyle];

  UITextView *textView = [self makeTextViewWithAttributedText:content];
  blockView.contentView = textView;

  [stack addArrangedSubview:blockView];

  // Spoiler overlays for this text view
  [self attachOverlaysToTextView:textView styleConfig:styleConfig];
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
  itemStack.spacing = !isnan(listStyle.gap) ? listStyle.gap : 0;
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
    [self attachOverlaysToTextView:textView styleConfig:styleConfig];
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
  inner.spacing = !isnan(blockquoteStyle.gap) ? blockquoteStyle.gap : 0;
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
  // Create with TextKit 1 from the start. The spoiler and mention
  // overlays need NSLayoutManager access for glyph-level rect
  // queries. If we let UITextView start in TextKit 2 mode, the
  // first .layoutManager access triggers a noisy compatibility
  // mode fallback warning.
  NSTextStorage *storage = [[NSTextStorage alloc] initWithAttributedString:text];
  NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
  [storage addLayoutManager:layoutManager];
  NSTextContainer *container = [[NSTextContainer alloc] initWithSize:CGSizeZero];
  container.widthTracksTextView = YES;
  [layoutManager addTextContainer:container];

  MarkdownInternalTextView *textView =
      [[MarkdownInternalTextView alloc] initWithFrame:CGRectZero
                                        textContainer:container];
  // Empty linkTextAttributes tells UITextView not to override the
  // attributed string's own color / underline / etc. on ranges that
  // have NSLinkAttributeName set. Otherwise it forces its tint color
  // and ignores whatever our LinkRenderer put on the string.
  textView.linkTextAttributes = @{};
  textView.editable = NO;
  textView.scrollEnabled = NO;
  textView.textContainerInset = UIEdgeInsetsZero;
  textView.textContainer.lineFragmentPadding = 0;
  textView.backgroundColor = [UIColor clearColor];
  textView.dataDetectorTypes = UIDataDetectorTypeNone;
  textView.delegate = self;

  // Fast link-tap recognizer — fires on touch-up. For quick taps
  // this beats UITextView's delayed internal recognizer. For slower
  // taps UITextView's recognizer fires first and UIKit cancels ours
  // (the delegate handles that case). Long-press and visual press
  // feedback are unaffected because we don't block any of
  // UITextView's internal recognizers.
  UITapGestureRecognizer *linkTap =
      [[UITapGestureRecognizer alloc] initWithTarget:self
                                              action:@selector(handleLinkTap:)];
  linkTap.cancelsTouchesInView = NO;
  [textView addGestureRecognizer:linkTap];

  return textView;
}

- (void)attachOverlaysToTextView:(UITextView *)textView
                     styleConfig:(StyleConfig *)styleConfig {
  // Spoilers — tap-to-reveal overlay with press feedback.
  MarkdownSpoilerOverlay *spoilerOverlay =
      [[MarkdownSpoilerOverlay alloc] initWithTextView:textView];

  MarkdownElementStyle *spoilerStyle = styleConfig.spoiler;
  if (spoilerStyle.backgroundColor) {
    spoilerOverlay.overlayColor = spoilerStyle.backgroundColor;
  }
  spoilerOverlay.cornerRadius = !isnan(spoilerStyle.borderRadius) ? spoilerStyle.borderRadius : 0;
  [_spoilerOverlays addObject:spoilerOverlay];

  // Mentions — transparent highlight-on-press overlay that fires
  // onMentionPress on tap-up. Replaces the old NSLinkAttributeName
  // path so users can't long-press into the system link menu or
  // drag the mention range out of the text view.
  MarkdownMentionOverlay *mentionOverlay =
      [[MarkdownMentionOverlay alloc] initWithTextView:textView];

  __weak __typeof(self) weakSelf = self;
  mentionOverlay.onPress = ^(NSDictionary *mention) {
    [weakSelf emitMentionPressForData:mention];
  };
  [_mentionOverlays addObject:mentionOverlay];

  // Rebuild overlay rects every time the text view lays out — they
  // depend on computed line fragments, which only become accurate
  // after the view has a real width. Without this the overlays are
  // sized against the zero bounds the text view has at construction
  // time and end up as one giant rect on the first line.
  if ([textView isKindOfClass:[MarkdownInternalTextView class]]) {
    __weak MarkdownSpoilerOverlay *weakSpoiler = spoilerOverlay;
    __weak MarkdownMentionOverlay *weakMention = mentionOverlay;
    ((MarkdownInternalTextView *)textView).onLayoutSubviews = ^{
      [weakSpoiler updateOverlays];
      [weakMention updateOverlays];
    };
  }
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
    // Tap — for quick taps the UITapGestureRecognizer on the text
    // view fires first and UIKit cancels UITextView's internal
    // recognizer, so this delegate method is never called. For
    // slower taps UITextView's recognizer wins and cancels ours,
    // so we emit here as a fallback.
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

#pragma mark - Link tap

- (void)handleLinkTap:(UITapGestureRecognizer *)recognizer {
  UITextView *textView = (UITextView *)recognizer.view;
  CGPoint point = [recognizer locationInView:textView];
  NSURL *url = [self linkURLAtPoint:point inTextView:textView];
  if (!url || !_eventEmitter) return;

  const auto &eventEmitter =
      static_cast<const MarkdownViewEventEmitter &>(*_eventEmitter);
  eventEmitter.onLinkPress({
      .url = std::string([[url absoluteString] UTF8String]),
      .title = std::string(""),
  });
}

#pragma mark - Table pan

- (void)handleTablePan:(UIPanGestureRecognizer *)recognizer {
  if (recognizer.state == UIGestureRecognizerStateBegan) {
    _panTargetTable = [self findScrollableTableAtPoint:
        [recognizer locationInView:self]];
  }

  MarkdownTableView *table = _panTargetTable;
  if (!table) return;

  CGPoint translation = [recognizer translationInView:self];
  CGFloat maxOffset =
      table.contentSize.width - table.bounds.size.width;
  CGFloat newX = table.contentOffset.x - translation.x;
  newX = MAX(0, MIN(maxOffset, newX));
  [table setContentOffset:CGPointMake(newX, 0) animated:NO];
  [recognizer setTranslation:CGPointZero inView:self];

  if (recognizer.state == UIGestureRecognizerStateEnded ||
      recognizer.state == UIGestureRecognizerStateCancelled) {
    _panTargetTable = nil;
  }
}

/// Finds a scrollable MarkdownTableView at `point` (in self's
/// coordinate space) by hit-testing the internal view tree.
- (nullable MarkdownTableView *)findScrollableTableAtPoint:
    (CGPoint)point {
  CGPoint basePoint = [self convertPoint:point toView:_baseContainer];
  UIView *hitView = [_baseContainer hitTest:basePoint withEvent:nil];
  return [self scrollableTableAncestorOf:hitView];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gr {
  if (gr != _tablePanGR) return YES;

  // Only begin for predominantly-horizontal pans over scrollable
  // tables. Vertical pans are left to the parent FlatList / ScrollView.
  UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gr;
  CGPoint velocity = [pan velocityInView:self];
  if (fabs(velocity.x) <= fabs(velocity.y)) return NO;

  return [self findScrollableTableAtPoint:
      [pan locationInView:self]] != nil;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:
        (UIGestureRecognizer *)other {
  // Allow simultaneous recognition with everything — we only drive
  // the table's contentOffset and don't interfere with other
  // gestures (FlatList scroll, etc.).
  if (gestureRecognizer == _tablePanGR) return YES;
  return NO;
}

#pragma mark - Mention press

- (void)emitMentionPressForData:(NSDictionary *)mention {
  if (!_eventEmitter || ![mention isKindOfClass:[NSDictionary class]]) return;

  NSString *type = mention[@"type"] ?: @"";
  NSString *mentionId = mention[@"id"] ?: @"";
  NSString *name = mention[@"name"] ?: @"";
  NSDictionary *extras = mention[@"props"];
  if (![extras isKindOfClass:[NSDictionary class]]) extras = @{};

  // Serialize extras as JSON so they can travel through the Fabric
  // event payload (which only supports primitive fields). The JS
  // side (Markdown.tsx) parses this back into a Record<string,string>
  // before invoking the user's onMentionPress callback.
  NSString *propsJson = @"{}";
  NSError *jsonError = nil;
  NSData *data = [NSJSONSerialization dataWithJSONObject:extras
                                                 options:0
                                                   error:&jsonError];
  if (!jsonError && data) {
    propsJson =
        [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"{}";
  }

  const auto &eventEmitter =
      static_cast<const MarkdownViewEventEmitter &>(*_eventEmitter);
  eventEmitter.onMentionPress({
      .mentionType = std::string([type UTF8String]),
      .mentionId = std::string([mentionId UTF8String]),
      .mentionName = std::string([name UTF8String]),
      .mentionProps = std::string([propsJson UTF8String]),
  });
}

#pragma mark - Image press

- (void)emitImagePressForURL:(NSURL *)url size:(CGSize)size {
  if (!_eventEmitter || !url) return;
  const auto &eventEmitter =
      static_cast<const MarkdownViewEventEmitter &>(*_eventEmitter);
  eventEmitter.onImagePress({
      .url = std::string([[url absoluteString] UTF8String]),
      .width = static_cast<double>(size.width),
      .height = static_cast<double>(size.height),
  });
}

#pragma mark - Remeasure after image load

- (void)handleImageSizeCacheUpdate:(NSNotification *)note {
  // A block image anywhere in the process just finished loading
  // (or a caller pre-seeded a new entry). Invalidate the measurer
  // result cache — entries in it might have been computed against
  // the old default height — and bump the shadow node's state
  // revision to force Yoga to re-call measureContent.
  [MarkdownMeasurer clearCache];
  [self markNeedsRemeasure];
}

- (void)updateState:(const facebook::react::State::Shared &)state
           oldState:(const facebook::react::State::Shared &)oldState {
  _markdownState =
      std::static_pointer_cast<const MarkdownViewShadowNode::ConcreteState>(
          state);
}

- (void)prepareForRecycle {
  [super prepareForRecycle];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self clearSegments];
  _currentMarkdown = nil;
  _currentStyleJSON = nil;
  _markdownState.reset();
}

- (void)markNeedsRemeasure {
  if (!_markdownState) return;

  _measureRevision += 1;
  int64_t revision = _measureRevision;
  _markdownState->updateState(
      [revision](const MarkdownViewState &oldData)
          -> std::shared_ptr<const MarkdownViewState> {
        MarkdownViewState newData = oldData;
        newData.revision = revision;
        return std::make_shared<const MarkdownViewState>(newData);
      });
}

@end

Class<RCTComponentViewProtocol> MarkdownViewCls(void) {
  return MarkdownView.class;
}
