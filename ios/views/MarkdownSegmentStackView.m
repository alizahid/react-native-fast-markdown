#import "MarkdownSegmentStackView.h"

#import "MarkdownBlockView.h"

@implementation MarkdownSegmentStackView {
  NSMutableArray<UIView *> *_segments;
}

/// Returns the width to allocate for `segment` given the stack's
/// available width. Most blocks get stretched to the full width so
/// the column layout is consistent. Image blocks — which set
/// `huggingContent` — instead get their preferred width from
/// sizeThatFits, clamped to the available width.
static CGFloat SegmentWidth(UIView *segment, CGFloat availableWidth) {
  if ([segment isKindOfClass:[MarkdownBlockView class]] &&
      ((MarkdownBlockView *)segment).huggingContent) {
    CGSize preferred =
        [segment sizeThatFits:CGSizeMake(availableWidth, CGFLOAT_MAX)];
    if (preferred.width > 0 && preferred.width < availableWidth) {
      return preferred.width;
    }
  }
  return availableWidth;
}

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _segments = [NSMutableArray new];
  }
  return self;
}

- (NSArray<UIView *> *)arrangedSubviews {
  return [_segments copy];
}

- (void)addArrangedSubview:(UIView *)view {
  if (!view) return;
  [_segments addObject:view];
  [self addSubview:view];
  [self setNeedsLayout];
}

- (void)removeAllArrangedSubviews {
  for (UIView *view in _segments) {
    [view removeFromSuperview];
  }
  [_segments removeAllObjects];
  [self setNeedsLayout];
}

- (CGSize)sizeThatFits:(CGSize)size {
  CGFloat width = size.width;
  CGFloat totalHeight = 0;
  NSInteger visibleCount = 0;

  for (UIView *segment in _segments) {
    if (segment.hidden) continue;
    CGFloat segW = SegmentWidth(segment, width);
    CGSize segSize = [segment sizeThatFits:CGSizeMake(segW, CGFLOAT_MAX)];
    totalHeight += segSize.height;
    visibleCount++;
  }

  if (visibleCount > 1) {
    totalHeight += _spacing * (visibleCount - 1);
  }

  return CGSizeMake(width, totalHeight);
}

- (void)layoutSubviews {
  [super layoutSubviews];

  CGFloat width = self.bounds.size.width;
  if (width <= 0) return;

  CGFloat y = 0;
  BOOL first = YES;

  for (UIView *segment in _segments) {
    if (segment.hidden) continue;
    CGFloat segW = SegmentWidth(segment, width);
    CGSize segSize = [segment sizeThatFits:CGSizeMake(segW, CGFLOAT_MAX)];
    if (!first) y += _spacing;
    segment.frame = CGRectMake(0, y, segW, segSize.height);
    y += segSize.height;
    first = NO;
  }
}

@end
