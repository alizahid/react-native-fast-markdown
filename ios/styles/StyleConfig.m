#import "StyleConfig.h"

@implementation MarkdownElementStyle

- (UIFont *)resolvedFont {
  if (_font) return _font;

  // fontSize comes from JS — if it's 0, caller didn't configure it
  CGFloat size = _fontSize;
  if (size <= 0) return nil;

  UIFontWeight weight = UIFontWeightRegular;

  if (_fontWeight) {
    if ([_fontWeight isEqualToString:@"bold"]) {
      weight = UIFontWeightBold;
    } else if ([_fontWeight isEqualToString:@"600"]) {
      weight = UIFontWeightSemibold;
    } else if ([_fontWeight isEqualToString:@"500"]) {
      weight = UIFontWeightMedium;
    } else if ([_fontWeight isEqualToString:@"300"]) {
      weight = UIFontWeightLight;
    }
  }

  if (_fontFamily && ![_fontFamily isEqualToString:@"System"]) {
    UIFont *customFont = [UIFont fontWithName:_fontFamily size:size];
    if (customFont) {
      if (weight != UIFontWeightRegular) {
        UIFontDescriptor *descriptor = [customFont.fontDescriptor
            fontDescriptorWithSymbolicTraits:(weight >= UIFontWeightBold
                                                 ? UIFontDescriptorTraitBold
                                                 : 0)];
        if (descriptor) {
          return [UIFont fontWithDescriptor:descriptor size:size];
        }
      }
      return customFont;
    }
  }

  UIFont *font = [UIFont systemFontOfSize:size weight:weight];

  if ([_fontStyle isEqualToString:@"italic"]) {
    UIFontDescriptor *descriptor = [font.fontDescriptor
        fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitItalic];
    if (descriptor) {
      return [UIFont fontWithDescriptor:descriptor size:size];
    }
  }

  return font;
}

- (UIEdgeInsets)resolvedPaddingInsets {
  // Specific edges override paddingHorizontal/paddingVertical which override padding
  CGFloat top = _paddingTop > 0
      ? _paddingTop
      : (_paddingVertical > 0 ? _paddingVertical : _padding);
  CGFloat bottom = _paddingBottom > 0
      ? _paddingBottom
      : (_paddingVertical > 0 ? _paddingVertical : _padding);
  CGFloat left = _paddingLeft > 0
      ? _paddingLeft
      : (_paddingHorizontal > 0 ? _paddingHorizontal : _padding);
  CGFloat right = _paddingRight > 0
      ? _paddingRight
      : (_paddingHorizontal > 0 ? _paddingHorizontal : _padding);
  return UIEdgeInsetsMake(top, left, bottom, right);
}

- (void)applyViewStyleToView:(UIView *)view {
  if (_backgroundColor) {
    view.backgroundColor = _backgroundColor;
  }
  if (_borderRadius > 0) {
    view.layer.cornerRadius = _borderRadius;
    view.layer.masksToBounds = YES;
  }
  if (_borderWidth > 0) {
    view.layer.borderWidth = _borderWidth;
    if (_borderColor) {
      view.layer.borderColor = _borderColor.CGColor;
    }
  }
}

@end

#pragma mark - StyleConfig

@implementation StyleConfig

+ (instancetype)fromJSON:(NSString *)json {
  StyleConfig *config = [[StyleConfig alloc] init];
  if (!json || json.length == 0) return config;

  NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
  NSError *error;
  NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data
                                                       options:0
                                                         error:&error];
  if (error || ![dict isKindOfClass:[NSDictionary class]]) return config;

  config.text = [self elementStyleFromDict:dict[@"text"]];
  config.heading1 = [self elementStyleFromDict:dict[@"heading1"]];
  config.heading2 = [self elementStyleFromDict:dict[@"heading2"]];
  config.heading3 = [self elementStyleFromDict:dict[@"heading3"]];
  config.heading4 = [self elementStyleFromDict:dict[@"heading4"]];
  config.heading5 = [self elementStyleFromDict:dict[@"heading5"]];
  config.heading6 = [self elementStyleFromDict:dict[@"heading6"]];
  config.paragraph = [self elementStyleFromDict:dict[@"paragraph"]];
  config.strong = [self elementStyleFromDict:dict[@"strong"]];
  config.emphasis = [self elementStyleFromDict:dict[@"emphasis"]];
  config.strikethrough = [self elementStyleFromDict:dict[@"strikethrough"]];
  config.underline = [self elementStyleFromDict:dict[@"underline"]];
  config.code = [self elementStyleFromDict:dict[@"code"]];
  config.codeBlock = [self elementStyleFromDict:dict[@"codeBlock"]];
  config.link = [self elementStyleFromDict:dict[@"link"]];
  config.blockquote = [self elementStyleFromDict:dict[@"blockquote"]];
  config.listItem = [self elementStyleFromDict:dict[@"listItem"]];
  config.listBullet = [self elementStyleFromDict:dict[@"listBullet"]];

  // Tables
  config.table = [self elementStyleFromDict:dict[@"table"]];
  config.tableRow = [self elementStyleFromDict:dict[@"tableRow"]];
  config.tableHeaderRow = [self elementStyleFromDict:dict[@"tableHeaderRow"]];
  config.tableCell = [self elementStyleFromDict:dict[@"tableCell"]];
  config.tableHeaderCell = [self elementStyleFromDict:dict[@"tableHeaderCell"]];

  config.thematicBreak = [self elementStyleFromDict:dict[@"thematicBreak"]];
  config.image = [self elementStyleFromDict:dict[@"image"]];
  config.mention = [self elementStyleFromDict:dict[@"mention"]];
  config.spoiler = [self elementStyleFromDict:dict[@"spoiler"]];

  return config;
}

+ (MarkdownElementStyle *)elementStyleFromDict:(NSDictionary *)dict {
  MarkdownElementStyle *style = [[MarkdownElementStyle alloc] init];
  if (![dict isKindOfClass:[NSDictionary class]]) return style;

  // Text properties
  if (dict[@"fontSize"]) style.fontSize = [dict[@"fontSize"] doubleValue];
  if (dict[@"fontWeight"]) style.fontWeight = dict[@"fontWeight"];
  if (dict[@"fontStyle"]) style.fontStyle = dict[@"fontStyle"];
  if (dict[@"fontFamily"]) style.fontFamily = dict[@"fontFamily"];
  if (dict[@"lineHeight"]) style.lineHeight = [dict[@"lineHeight"] doubleValue];
  if (dict[@"textDecorationLine"]) style.textDecorationLine = dict[@"textDecorationLine"];
  if (dict[@"textAlign"]) style.textAlign = dict[@"textAlign"];

  // Padding
  if (dict[@"padding"]) style.padding = [dict[@"padding"] doubleValue];
  if (dict[@"paddingHorizontal"]) style.paddingHorizontal = [dict[@"paddingHorizontal"] doubleValue];
  if (dict[@"paddingVertical"]) style.paddingVertical = [dict[@"paddingVertical"] doubleValue];
  if (dict[@"paddingTop"]) style.paddingTop = [dict[@"paddingTop"] doubleValue];
  if (dict[@"paddingBottom"]) style.paddingBottom = [dict[@"paddingBottom"] doubleValue];
  if (dict[@"paddingLeft"]) style.paddingLeft = [dict[@"paddingLeft"] doubleValue];
  if (dict[@"paddingRight"]) style.paddingRight = [dict[@"paddingRight"] doubleValue];

  // Margin
  if (dict[@"marginVertical"]) style.marginVertical = [dict[@"marginVertical"] doubleValue];

  // Border
  if (dict[@"borderWidth"]) style.borderWidth = [dict[@"borderWidth"] doubleValue];
  if (dict[@"borderRadius"]) style.borderRadius = [dict[@"borderRadius"] doubleValue];
  if (dict[@"borderLeftWidth"]) style.borderLeftWidth = [dict[@"borderLeftWidth"] doubleValue];
  if (dict[@"borderRightWidth"]) style.borderRightWidth = [dict[@"borderRightWidth"] doubleValue];
  if (dict[@"borderTopWidth"]) style.borderTopWidth = [dict[@"borderTopWidth"] doubleValue];
  if (dict[@"borderBottomWidth"]) style.borderBottomWidth = [dict[@"borderBottomWidth"] doubleValue];

  // Size
  if (dict[@"height"]) style.height = [dict[@"height"] doubleValue];
  if (dict[@"width"]) style.width = [dict[@"width"] doubleValue];

  // Colors (processColor returns ARGB integer on native)
  style.color = [self colorFromValue:dict[@"color"]];
  style.backgroundColor = [self colorFromValue:dict[@"backgroundColor"]];
  style.borderColor = [self colorFromValue:dict[@"borderColor"]];
  style.borderLeftColor = [self colorFromValue:dict[@"borderLeftColor"]];
  style.borderRightColor = [self colorFromValue:dict[@"borderRightColor"]];
  style.borderTopColor = [self colorFromValue:dict[@"borderTopColor"]];
  style.borderBottomColor = [self colorFromValue:dict[@"borderBottomColor"]];

  return style;
}

+ (UIColor *)colorFromValue:(id)value {
  if (!value || [value isKindOfClass:[NSNull class]]) return nil;

  if ([value isKindOfClass:[NSNumber class]]) {
    uint32_t argb = [value unsignedIntValue];
    CGFloat a = ((argb >> 24) & 0xFF) / 255.0;
    CGFloat r = ((argb >> 16) & 0xFF) / 255.0;
    CGFloat g = ((argb >> 8) & 0xFF) / 255.0;
    CGFloat b = (argb & 0xFF) / 255.0;
    return [UIColor colorWithRed:r green:g blue:b alpha:a];
  }

  if ([value isKindOfClass:[NSString class]]) {
    NSString *hex = value;
    if ([hex hasPrefix:@"#"]) {
      hex = [hex substringFromIndex:1];
    }
    if (hex.length == 6) {
      unsigned int rgb;
      [[NSScanner scannerWithString:hex] scanHexInt:&rgb];
      return [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0
                             green:((rgb >> 8) & 0xFF) / 255.0
                              blue:(rgb & 0xFF) / 255.0
                             alpha:1.0];
    }
  }

  return nil;
}

- (MarkdownElementStyle *)styleForHeadingLevel:(NSInteger)level {
  switch (level) {
    case 1: return self.heading1;
    case 2: return self.heading2;
    case 3: return self.heading3;
    case 4: return self.heading4;
    case 5: return self.heading5;
    case 6: return self.heading6;
    default: return self.heading1;
  }
}

@end
