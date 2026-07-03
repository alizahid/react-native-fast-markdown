#import "FMDBlockStackView.h"

#import "FMDBlockTextView.h"
#import "FMDBoxViews.h"
#import "FMDImageView.h"
#import "FMDTableView.h"

@implementation FMDBlockStackView {
  NSArray<FMDMeasuredBlock *> *_measured;
  CGFloat _gap;
}

- (void)setBlocks:(NSArray<FMDMeasuredBlock *> *)blocks gap:(CGFloat)gap {
  _measured = blocks;
  _gap = gap;

  for (UIView *subview in [self.subviews copy]) {
    [subview removeFromSuperview];
  }
  for (FMDMeasuredBlock *measured in blocks) {
    [self addSubview:[self createViewFor:measured]];
  }
  [self setNeedsLayout];
}

- (UIView *)createViewFor:(FMDMeasuredBlock *)measured {
  switch (measured.block.kind) {
    case FMDBlockKindText: {
      FMDBlockTextView *view = [[FMDBlockTextView alloc] initWithFrame:CGRectZero];
      view.host = self.host;
      view.spoilerColor = measured.block.spoilerColor;
      view.spoilerRadius = measured.block.spoilerRadius;
      view.attributedText = measured.block.attributedText;
      return view;
    }
    case FMDBlockKindCode: {
      FMDCodeBlockView *view = [[FMDCodeBlockView alloc] initWithFrame:CGRectZero];
      [view bind:measured];
      return view;
    }
    case FMDBlockKindQuote: {
      FMDQuoteView *view = [[FMDQuoteView alloc] initWithFrame:CGRectZero];
      [view bind:measured gap:_gap host:self.host];
      return view;
    }
    case FMDBlockKindList: {
      FMDListBlockView *view = [[FMDListBlockView alloc] initWithFrame:CGRectZero];
      [view bind:measured gap:_gap host:self.host];
      return view;
    }
    case FMDBlockKindDivider: {
      UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
      view.backgroundColor = measured.block.dividerColor;
      return view;
    }
    case FMDBlockKindImage: {
      FMDImageView *view = [[FMDImageView alloc] initWithFrame:CGRectZero];
      view.host = self.host;
      [view bind:measured.block];
      return view;
    }
    case FMDBlockKindTable: {
      FMDTableView *view = [[FMDTableView alloc] initWithFrame:CGRectZero];
      [view bind:measured host:self.host];
      return view;
    }
  }
  return [[UIView alloc] initWithFrame:CGRectZero];
}


// Never the hit view itself: markdown touches belong to the host component
// view; only nested scrollers (code blocks, tables) claim touches.
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
  UIView *hit = [super hitTest:point withEvent:event];
  return hit == self ? nil : hit;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  const CGFloat width = self.bounds.size.width;
  CGFloat y = 0;
  for (NSUInteger i = 0; i < _measured.count && i < self.subviews.count; i++) {
    FMDMeasuredBlock *measured = _measured[i];
    const CGFloat childWidth = measured.block.kind == FMDBlockKindImage
        ? MIN(measured.contentWidth, width)
        : width;
    self.subviews[i].frame = CGRectMake(0, y, childWidth, measured.height);
    y += measured.height;
    if (i + 1 < _measured.count) {
      y += _gap;
    }
  }
}

@end
