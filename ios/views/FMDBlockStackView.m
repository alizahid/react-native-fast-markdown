#import "FMDBlockStackView.h"

#import "FMDBlockTextView.h"
#import "FMDBoxViews.h"
#import "FMDImageView.h"

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
      [view bind:measured gap:_gap onImageIntrinsicSize:self.onImageIntrinsicSize];
      return view;
    }
    case FMDBlockKindList: {
      FMDListBlockView *view = [[FMDListBlockView alloc] initWithFrame:CGRectZero];
      [view bind:measured gap:_gap onImageIntrinsicSize:self.onImageIntrinsicSize];
      return view;
    }
    case FMDBlockKindDivider: {
      UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
      view.backgroundColor = measured.block.dividerColor;
      return view;
    }
    case FMDBlockKindImage: {
      FMDImageView *view = [[FMDImageView alloc] initWithFrame:CGRectZero];
      view.onIntrinsicSize = self.onImageIntrinsicSize;
      [view bind:measured.block];
      return view;
    }
  }
  return [[UIView alloc] initWithFrame:CGRectZero];
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
