#import "MarkdownSegmentStackView.h"

@implementation MarkdownSegmentStackView {
  NSMutableArray<UIView *> *_segments;
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
    CGSize segSize = [segment sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];
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
    CGSize segSize = [segment sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];
    if (!first) y += _spacing;
    segment.frame = CGRectMake(0, y, width, segSize.height);
    y += segSize.height;
    first = NO;
  }
}

@end
