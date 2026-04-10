#import "MarkdownInputView.h"

#import <React/RCTConversions.h>
#import <React/RCTFabricComponentsPlugins.h>
#import <react/renderer/components/MarkdownViewSpec/ComponentDescriptors.h>
#import <react/renderer/components/MarkdownViewSpec/EventEmitters.h>
#import <react/renderer/components/MarkdownViewSpec/Props.h>

using namespace facebook::react;

@implementation MarkdownInputView {
  UITextView *_textView;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<
      MarkdownInputViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _textView = [[UITextView alloc] initWithFrame:self.bounds];
    _textView.font = [UIFont systemFontOfSize:16];
    _textView.backgroundColor = [UIColor whiteColor];
    [self addSubview:_textView];
  }
  return self;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  _textView.frame = self.bounds;
}

- (void)updateProps:(const Props::Shared &)props
           oldProps:(const Props::Shared &)oldProps {
  const auto &newProps =
      *std::static_pointer_cast<const MarkdownInputViewProps>(props);

  if (!oldProps) {
    NSString *defaultValue =
        [NSString stringWithUTF8String:newProps.defaultValue.c_str()];
    if (defaultValue.length > 0) {
      _textView.text = defaultValue;
    }
  }

  _textView.editable = newProps.editable;

  [super updateProps:props oldProps:oldProps];
}

- (void)handleCommand:(const NSString *)commandName
                 args:(const NSArray *)args {
  if ([commandName isEqualToString:@"focus"]) {
    [_textView becomeFirstResponder];
  } else if ([commandName isEqualToString:@"blur"]) {
    [_textView resignFirstResponder];
  } else if ([commandName isEqualToString:@"setValue"]) {
    _textView.text = args[0];
  }
}

@end

Class<RCTComponentViewProtocol> MarkdownInputViewCls(void) {
  return MarkdownInputView.class;
}
