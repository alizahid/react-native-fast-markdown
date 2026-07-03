#import "FMDBoxViews.h"

#import "../render/FMDRenderedContent.h"
#import "FMDBlockStackView.h"
#import "FMDBlockTextView.h"

@implementation FMDNestedScrollView {
  __weak UIControl *_trackingControl;
}

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    self.delegate = self;
  }
  return self;
}

// As the hit view this scroller consumes the raw touch stream, which starves
// UIControl-based wrappers: react-native-gesture-handler's button fires
// presses from UIControl events, and a control refuses to track touches
// hit-tested to another view. Synthesize the control events instead — press
// down on touch start, press on a clean touch up, cancel when the pan takes
// the touches — so a tap on a code block or table still presses the
// wrapping card while drags scroll without pressing.
- (nullable UIControl *)fmdAncestorControl {
  UIView *view = self.superview;
  while (view != nil) {
    if ([view isKindOfClass:[UIControl class]]) {
      return (UIControl *)view;
    }
    view = view.superview;
  }
  return nil;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  [super touchesBegan:touches withEvent:event];
  _trackingControl = [self fmdAncestorControl];
  [_trackingControl sendActionsForControlEvents:UIControlEventTouchDown];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  [super touchesEnded:touches withEvent:event];
  [_trackingControl sendActionsForControlEvents:UIControlEventTouchUpInside];
  _trackingControl = nil;
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  [super touchesCancelled:touches withEvent:event];
  [_trackingControl sendActionsForControlEvents:UIControlEventTouchCancel];
  _trackingControl = nil;
}

// This scroller is not a React view, so nothing cancels the JS responder
// (an RN Pressable wrapping the markdown view) when a drag starts here —
// React only cancels for its own scroll views. Kill the surface touch
// handler's active touches the way RCTTouchHandler itself cancels: an
// enabled toggle.
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
  UIView *view = self.superview;
  while (view != nil) {
    for (UIGestureRecognizer *recognizer in view.gestureRecognizers) {
      if ([NSStringFromClass(recognizer.class) containsString:@"TouchHandler"]) {
        recognizer.enabled = NO;
        recognizer.enabled = YES;
        return;
      }
    }
    view = view.superview;
  }
}

@end

// Shared background + border painting on a host view's layer tree.
static void FMDApplyBox(UIView *view, FMDLayoutStyle *style) {
  view.backgroundColor = style.backgroundColor ?: UIColor.clearColor;
  view.layer.cornerRadius = style.borderRadius;
  view.layer.cornerCurve =
      style.continuousCorners ? kCACornerCurveContinuous : kCACornerCurveCircular;
  view.layer.masksToBounds = style.borderRadius > 0;
}

@interface FMDBorderView : UIView
@property (nonatomic, strong, nullable) FMDLayoutStyle *boxStyle;
@end

@implementation FMDBorderView

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    self.backgroundColor = UIColor.clearColor;
    self.userInteractionEnabled = NO;
    self.contentMode = UIViewContentModeRedraw;
  }
  return self;
}

- (void)drawRect:(CGRect)rect {
  FMDLayoutStyle *style = self.boxStyle;
  if (style == nil) {
    return;
  }
  CGContextRef context = UIGraphicsGetCurrentContext();
  const CGSize size = self.bounds.size;

  if (style.borderLeftWidth > 0 && style.borderLeftColor != nil) {
    CGContextSetFillColorWithColor(context, style.borderLeftColor.CGColor);
    if (style.borderRadius > 0) {
      UIBezierPath *path = [UIBezierPath
          bezierPathWithRoundedRect:CGRectMake(0, 0, style.borderLeftWidth, size.height)
                       cornerRadius:style.borderRadius / 2];
      [path fill];
    } else {
      CGContextFillRect(context, CGRectMake(0, 0, style.borderLeftWidth, size.height));
    }
  }
  if (style.borderRightWidth > 0 && style.borderRightColor != nil) {
    CGContextSetFillColorWithColor(context, style.borderRightColor.CGColor);
    CGContextFillRect(
        context,
        CGRectMake(size.width - style.borderRightWidth, 0, style.borderRightWidth, size.height));
  }
  if (style.borderTopWidth > 0 && style.borderTopColor != nil) {
    CGContextSetFillColorWithColor(context, style.borderTopColor.CGColor);
    CGContextFillRect(context, CGRectMake(0, 0, size.width, style.borderTopWidth));
  }
  if (style.borderBottomWidth > 0 && style.borderBottomColor != nil) {
    CGContextSetFillColorWithColor(context, style.borderBottomColor.CGColor);
    CGContextFillRect(
        context,
        CGRectMake(0, size.height - style.borderBottomWidth, size.width, style.borderBottomWidth));
  }
}

@end

@implementation FMDQuoteView {
  FMDMeasuredBlock *_measured;
  FMDBlockStackView *_stack;
  FMDBorderView *_borders;
}

- (void)bind:(FMDMeasuredBlock *)measured
         gap:(CGFloat)gap
        host:(nullable id<FMDMarkdownHost>)host {
  _measured = measured;
  if (_stack == nil) {
    _stack = [[FMDBlockStackView alloc] initWithFrame:CGRectZero];
    _borders = [[FMDBorderView alloc] initWithFrame:CGRectZero];
    [self addSubview:_stack];
    [self addSubview:_borders];
  }
  FMDApplyBox(self, measured.block.layoutStyle);
  _borders.boxStyle = measured.block.layoutStyle;
  _stack.host = host;
  [_stack setBlocks:measured.children gap:gap];
  [self setNeedsLayout];
}


// Never the hit view itself: markdown touches belong to the host component
// view; only nested scrollers (code blocks, tables) claim touches.
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
  UIView *hit = [super hitTest:point withEvent:event];
  return hit == self ? nil : hit;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  FMDLayoutStyle *style = _measured.block.layoutStyle;
  const CGFloat left = style.borderLeftWidth + style.paddingLeft;
  const CGFloat top = style.borderTopWidth + style.paddingTop;
  _stack.frame = CGRectMake(
      left,
      top,
      self.bounds.size.width - left - style.borderRightWidth - style.paddingRight,
      self.bounds.size.height - top - style.borderBottomWidth - style.paddingBottom);
  _borders.frame = self.bounds;
  [_borders setNeedsDisplay];
}

@end

@implementation FMDCodeBlockView {
  FMDMeasuredBlock *_measured;
  UIScrollView *_scroller;
  FMDBlockTextView *_text;
}

- (void)bind:(FMDMeasuredBlock *)measured {
  _measured = measured;
  if (_scroller == nil) {
    _scroller = [[FMDNestedScrollView alloc] initWithFrame:CGRectZero];
    _scroller.showsHorizontalScrollIndicator = NO;
    _scroller.showsVerticalScrollIndicator = NO;
    _scroller.alwaysBounceHorizontal = YES;
    _scroller.alwaysBounceVertical = NO;
    _scroller.delaysContentTouches = NO;
    _scroller.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    _text = [[FMDBlockTextView alloc] initWithFrame:CGRectZero];
    [_scroller addSubview:_text];
    [self addSubview:_scroller];
  }
  FMDApplyBox(self, measured.block.layoutStyle);
  _text.attributedText = measured.block.attributedText;
  [self setNeedsLayout];
}


// Never the hit view itself: markdown touches belong to the host component
// view; only nested scrollers (code blocks, tables) claim touches.
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
  UIView *hit = [super hitTest:point withEvent:event];
  return hit == self ? nil : hit;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  FMDLayoutStyle *style = _measured.block.layoutStyle;
  const CGFloat innerWidth =
      self.bounds.size.width - style.paddingLeft - style.paddingRight;
  _scroller.frame = CGRectMake(
      style.paddingLeft, style.paddingTop, innerWidth, _measured.textHeight);
  _text.frame = CGRectMake(0, 0, _measured.contentWidth, _measured.textHeight);
  _scroller.contentSize = CGSizeMake(_measured.contentWidth, _measured.textHeight);
}

@end

@implementation FMDListBlockView {
  FMDMeasuredBlock *_measured;
  CGFloat _gap;
}

- (void)bind:(FMDMeasuredBlock *)measured
         gap:(CGFloat)gap
        host:(nullable id<FMDMarkdownHost>)host {
  _measured = measured;
  _gap = gap;
  for (UIView *subview in [self.subviews copy]) {
    [subview removeFromSuperview];
  }
  FMDBlock *block = measured.block;
  for (NSUInteger i = 0; i < block.rows.count; i++) {
    FMDBlockTextView *marker = [[FMDBlockTextView alloc] initWithFrame:CGRectZero];
    marker.attributedText = block.rows[i].marker;
    [self addSubview:marker];

    FMDBlockStackView *content = [[FMDBlockStackView alloc] initWithFrame:CGRectZero];
    content.host = host;
    [content setBlocks:measured.rowContents[i] gap:gap];
    [self addSubview:content];
  }
  [self setNeedsLayout];
}


// Never the hit view itself: markdown touches belong to the host component
// view; only nested scrollers (code blocks, tables) claim touches.
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
  UIView *hit = [super hitTest:point withEvent:event];
  return hit == self ? nil : hit;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  FMDBlock *block = _measured.block;
  const CGFloat markerX = block.listMarginLeft + block.markerMarginLeft;
  const CGFloat contentX = markerX + block.markerWidth;
  const CGFloat contentWidth = _measured.contentWidth;

  CGFloat y = 0;
  for (NSUInteger i = 0; i < block.rows.count; i++) {
    const CGFloat markerHeight = _measured.markerHeights[i].doubleValue;
    const CGFloat contentHeight =
        [FMDRenderedContent stackHeight:_measured.rowContents[i] gap:_gap];
    const CGFloat rowHeight = MAX(markerHeight, contentHeight);

    UIView *markerView = self.subviews[i * 2];
    UIView *contentView = self.subviews[i * 2 + 1];
    markerView.frame = CGRectMake(markerX, y, block.markerWidth, markerHeight);
    contentView.frame = CGRectMake(contentX, y, contentWidth, contentHeight);

    y += rowHeight;
    if (i + 1 < block.rows.count) {
      y += _gap / 2;
    }
  }
}

@end
