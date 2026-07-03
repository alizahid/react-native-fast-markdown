#import "FMDImageView.h"

#import "../image/FMDImageLoader.h"

@implementation FMDImageView {
  FMDBlock *_block;
  UIImageView *_imageView;
}

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    _imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _imageView.contentMode = UIViewContentModeScaleAspectFit;
    [self addSubview:_imageView];
  }
  return self;
}

// Hit-test transparent: the host component view owns all touch handling.
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
  return nil;
}

- (nullable NSString *)imageUrl {
  return _block.imageUrl;
}

- (void)bind:(FMDBlock *)block {
  _block = block;
  self.backgroundColor = block.imageBackground ?: UIColor.clearColor;
  self.layer.cornerRadius = block.imageBorderRadius;
  self.layer.masksToBounds = block.imageBorderRadius > 0;

  NSString *url = block.imageUrl ?: @"";
  UIImage *cached = [FMDImageLoader cachedImageForUrl:url];
  _imageView.image = cached;
  if (cached != nil) {
    // Report even for cache hits so a fresh view (relaunch with a warm disk
    // cache, recycling) still resizes un-presized images.
    [self.host imageIntrinsicSize:cached.size forUrl:url];
  }
  if (cached == nil && url.length > 0) {
    __weak FMDImageView *weakSelf = self;
    [FMDImageLoader loadUrl:url
                 completion:^(UIImage *image) {
                   FMDImageView *strongSelf = weakSelf;
                   if (strongSelf == nil || image == nil ||
                       ![strongSelf->_block.imageUrl isEqualToString:url]) {
                     return;
                   }
                   strongSelf->_imageView.image = image;
                   [strongSelf.host imageIntrinsicSize:image.size forUrl:url];
                 }];
  }
}

- (void)layoutSubviews {
  [super layoutSubviews];
  _imageView.frame = self.bounds;
}

@end
