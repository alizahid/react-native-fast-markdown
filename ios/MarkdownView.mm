#import "MarkdownView.h"

#import <React/RCTConversions.h>
#import <React/RCTFabricComponentsPlugins.h>
#import <react/renderer/components/MarkdownViewSpec/ComponentDescriptors.h>
#import <react/renderer/components/MarkdownViewSpec/EventEmitters.h>
#import <react/renderer/components/MarkdownViewSpec/Props.h>

using namespace facebook::react;

@implementation MarkdownView {
  UILabel *_label;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<MarkdownViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _label = [[UILabel alloc] initWithFrame:self.bounds];
    _label.numberOfLines = 0;
    _label.backgroundColor = [UIColor whiteColor];
    [self addSubview:_label];
  }
  return self;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  _label.frame = self.bounds;
}

- (void)updateProps:(const Props::Shared &)props
           oldProps:(const Props::Shared &)oldProps {
  const auto &newViewProps =
      *std::static_pointer_cast<const MarkdownViewProps>(props);

  NSString *markdown =
      [NSString stringWithUTF8String:newViewProps.markdown.c_str()];

  _label.text = markdown;

  [super updateProps:props oldProps:oldProps];
}

@end

Class<RCTComponentViewProtocol> MarkdownViewCls(void) {
  return MarkdownView.class;
}
