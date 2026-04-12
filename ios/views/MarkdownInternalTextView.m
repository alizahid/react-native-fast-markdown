#import "MarkdownInternalTextView.h"

@implementation MarkdownInternalTextView

- (void)layoutSubviews {
  [super layoutSubviews];
  if (_onLayoutSubviews) {
    _onLayoutSubviews();
  }
}

@end
