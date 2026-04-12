#import "StyleConfig.h"

#import <React/RCTConvert.h>

@implementation MarkdownElementStyle

#pragma mark - Font resolution

- (UIFont *)resolvedFont {
  return [self resolvedFontWithBase:nil];
}

- (UIFont *)resolvedFontWithBase:(UIFont *)baseFont {
  CGFloat size = _fontSize > 0
      ? _fontSize
      : (baseFont ? baseFont.pointSize : 0);
  if (size <= 0) return baseFont;

  NSString *family = _fontFamily ?: baseFont.familyName;

  // Start from base font's traits if available
  UIFontDescriptorSymbolicTraits traits =
      baseFont ? baseFont.fontDescriptor.symbolicTraits : 0;

  if (_fontWeight) {
    if ([_fontWeight isEqualToString:@"bold"] ||
        [_fontWeight isEqualToString:@"600"] ||
        [_fontWeight isEqualToString:@"700"] ||
        [_fontWeight isEqualToString:@"800"] ||
        [_fontWeight isEqualToString:@"900"]) {
      traits |= UIFontDescriptorTraitBold;
    } else if ([_fontWeight isEqualToString:@"normal"] ||
               [_fontWeight isEqualToString:@"100"] ||
               [_fontWeight isEqualToString:@"200"] ||
               [_fontWeight isEqualToString:@"300"] ||
               [_fontWeight isEqualToString:@"400"] ||
               [_fontWeight isEqualToString:@"500"]) {
      traits &= ~UIFontDescriptorTraitBold;
    }
  }

  if (_fontStyle) {
    if ([_fontStyle isEqualToString:@"italic"]) {
      traits |= UIFontDescriptorTraitItalic;
    } else if ([_fontStyle isEqualToString:@"normal"]) {
      traits &= ~UIFontDescriptorTraitItalic;
    }
  }

  UIFont *resolved = nil;
  if (!family || [family isEqualToString:@"System"]) {
    UIFontWeight weight = (traits & UIFontDescriptorTraitBold)
        ? UIFontWeightBold
        : UIFontWeightRegular;
    resolved = [UIFont systemFontOfSize:size weight:weight];
    if (traits & UIFontDescriptorTraitItalic) {
      UIFontDescriptor *d =
          [resolved.fontDescriptor fontDescriptorWithSymbolicTraits:
              resolved.fontDescriptor.symbolicTraits | UIFontDescriptorTraitItalic];
      if (d) resolved = [UIFont fontWithDescriptor:d size:size];
    }
  } else {
    UIFont *base = [UIFont fontWithName:family size:size];
    if (base) {
      UIFontDescriptor *d =
          [base.fontDescriptor fontDescriptorWithSymbolicTraits:traits];
      resolved = d ? [UIFont fontWithDescriptor:d size:size] : base;
    }
  }

  return resolved ?: baseFont;
}

#pragma mark - Layout insets

- (UIEdgeInsets)resolvedPaddingInsets {
  // Specific edges override paddingHorizontal/paddingVertical which override padding.
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

- (UIEdgeInsets)resolvedMarginInsets {
  CGFloat top = _marginTop > 0
      ? _marginTop
      : (_marginVertical > 0 ? _marginVertical : _margin);
  CGFloat bottom = _marginBottom > 0
      ? _marginBottom
      : (_marginVertical > 0 ? _marginVertical : _margin);
  CGFloat left = _marginLeft > 0
      ? _marginLeft
      : (_marginHorizontal > 0 ? _marginHorizontal : _margin);
  CGFloat right = _marginRight > 0
      ? _marginRight
      : (_marginHorizontal > 0 ? _marginHorizontal : _margin);

  return UIEdgeInsetsMake(top, left, bottom, right);
}

- (UIEdgeInsets)resolvedBorderWidths {
  CGFloat top = _borderTopWidth > 0 ? _borderTopWidth : _borderWidth;
  CGFloat bottom = _borderBottomWidth > 0 ? _borderBottomWidth : _borderWidth;
  CGFloat left = _borderLeftWidth > 0 ? _borderLeftWidth : _borderWidth;
  CGFloat right = _borderRightWidth > 0 ? _borderRightWidth : _borderWidth;
  return UIEdgeInsetsMake(top, left, bottom, right);
}

- (UIColor *)resolvedBorderColorForEdge:(UIRectEdge)edge {
  switch (edge) {
    case UIRectEdgeTop:
      return _borderTopColor ?: _borderColor;
    case UIRectEdgeBottom:
      return _borderBottomColor ?: _borderColor;
    case UIRectEdgeLeft:
      return _borderLeftColor ?: _borderColor;
    case UIRectEdgeRight:
      return _borderRightColor ?: _borderColor;
    default:
      return _borderColor;
  }
}

- (CGFloat)resolvedRadiusForCorner:(UIRectCorner)corner {
  switch (corner) {
    case UIRectCornerTopLeft:
      return _borderTopLeftRadius > 0 ? _borderTopLeftRadius : _borderRadius;
    case UIRectCornerTopRight:
      return _borderTopRightRadius > 0 ? _borderTopRightRadius : _borderRadius;
    case UIRectCornerBottomLeft:
      return _borderBottomLeftRadius > 0 ? _borderBottomLeftRadius : _borderRadius;
    case UIRectCornerBottomRight:
      return _borderBottomRightRadius > 0 ? _borderBottomRightRadius : _borderRadius;
    default:
      return _borderRadius;
  }
}

- (BOOL)hasAnyBorder {
  UIEdgeInsets widths = [self resolvedBorderWidths];
  return widths.top > 0 || widths.bottom > 0 || widths.left > 0 || widths.right > 0;
}

- (BOOL)hasAnyRadius {
  return _borderRadius > 0 ||
         _borderTopLeftRadius > 0 || _borderTopRightRadius > 0 ||
         _borderBottomLeftRadius > 0 || _borderBottomRightRadius > 0;
}

- (BOOL)hasNonUniformBorders {
  UIEdgeInsets widths = [self resolvedBorderWidths];
  BOOL widthsDiffer = !(widths.top == widths.bottom &&
                        widths.bottom == widths.left &&
                        widths.left == widths.right);
  if (widthsDiffer) return YES;

  UIColor *top = [self resolvedBorderColorForEdge:UIRectEdgeTop];
  UIColor *bottom = [self resolvedBorderColorForEdge:UIRectEdgeBottom];
  UIColor *left = [self resolvedBorderColorForEdge:UIRectEdgeLeft];
  UIColor *right = [self resolvedBorderColorForEdge:UIRectEdgeRight];

  if ((top && bottom && ![top isEqual:bottom]) ||
      (top && left && ![top isEqual:left]) ||
      (top && right && ![top isEqual:right])) {
    return YES;
  }

  return NO;
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

  config.base = [self elementStyleFromDict:dict[@"base"]];

  config.paragraph = [self elementStyleFromDict:dict[@"paragraph"]];
  config.heading1 = [self elementStyleFromDict:dict[@"heading1"]];
  config.heading2 = [self elementStyleFromDict:dict[@"heading2"]];
  config.heading3 = [self elementStyleFromDict:dict[@"heading3"]];
  config.heading4 = [self elementStyleFromDict:dict[@"heading4"]];
  config.heading5 = [self elementStyleFromDict:dict[@"heading5"]];
  config.heading6 = [self elementStyleFromDict:dict[@"heading6"]];
  config.blockquote = [self elementStyleFromDict:dict[@"blockquote"]];
  config.codeBlock = [self elementStyleFromDict:dict[@"codeBlock"]];
  config.list = [self elementStyleFromDict:dict[@"list"]];
  config.listItem = [self elementStyleFromDict:dict[@"listItem"]];
  config.listBullet = [self elementStyleFromDict:dict[@"listBullet"]];
  config.thematicBreak = [self elementStyleFromDict:dict[@"thematicBreak"]];
  config.image = [self elementStyleFromDict:dict[@"image"]];

  config.table = [self elementStyleFromDict:dict[@"table"]];
  config.tableRow = [self elementStyleFromDict:dict[@"tableRow"]];
  config.tableHeaderRow = [self elementStyleFromDict:dict[@"tableHeaderRow"]];
  config.tableCell = [self elementStyleFromDict:dict[@"tableCell"]];
  config.tableHeaderCell = [self elementStyleFromDict:dict[@"tableHeaderCell"]];

  config.strong = [self elementStyleFromDict:dict[@"strong"]];
  config.emphasis = [self elementStyleFromDict:dict[@"emphasis"]];
  config.strikethrough = [self elementStyleFromDict:dict[@"strikethrough"]];
  config.code = [self elementStyleFromDict:dict[@"code"]];
  config.link = [self elementStyleFromDict:dict[@"link"]];
  config.mentionUser = [self elementStyleFromDict:dict[@"mentionUser"]];
  config.mentionChannel = [self elementStyleFromDict:dict[@"mentionChannel"]];
  config.mentionCommand = [self elementStyleFromDict:dict[@"mentionCommand"]];
  config.spoiler = [self elementStyleFromDict:dict[@"spoiler"]];

  return config;
}

+ (MarkdownElementStyle *)elementStyleFromDict:(NSDictionary *)dict {
  MarkdownElementStyle *style = [[MarkdownElementStyle alloc] init];
  if (![dict isKindOfClass:[NSDictionary class]]) return style;

  // Text properties
  style.color = [self colorFromValue:dict[@"color"]];
  if (dict[@"fontFamily"]) style.fontFamily = dict[@"fontFamily"];
  if (dict[@"fontSize"]) style.fontSize = [dict[@"fontSize"] doubleValue];
  if (dict[@"fontStyle"]) style.fontStyle = dict[@"fontStyle"];
  if (dict[@"fontWeight"]) style.fontWeight = dict[@"fontWeight"];
  if (dict[@"letterSpacing"]) style.letterSpacing = [dict[@"letterSpacing"] doubleValue];
  if (dict[@"lineHeight"]) style.lineHeight = [dict[@"lineHeight"] doubleValue];
  if (dict[@"textAlign"]) style.textAlign = dict[@"textAlign"];
  style.textDecorationColor = [self colorFromValue:dict[@"textDecorationColor"]];
  if (dict[@"textDecorationLine"]) style.textDecorationLine = dict[@"textDecorationLine"];
  if (dict[@"textDecorationStyle"]) style.textDecorationStyle = dict[@"textDecorationStyle"];

  // View properties
  style.backgroundColor = [self colorFromValue:dict[@"backgroundColor"]];

  if (dict[@"gap"]) style.gap = [dict[@"gap"] doubleValue];
  if (dict[@"width"]) style.width = [dict[@"width"] doubleValue];
  if (dict[@"height"]) style.height = [dict[@"height"] doubleValue];
  if (dict[@"maxWidth"]) style.maxWidth = [dict[@"maxWidth"] doubleValue];
  if (dict[@"maxHeight"]) style.maxHeight = [dict[@"maxHeight"] doubleValue];
  if (dict[@"objectFit"]) style.objectFit = dict[@"objectFit"];

  // Margin
  if (dict[@"margin"]) style.margin = [dict[@"margin"] doubleValue];
  if (dict[@"marginTop"]) style.marginTop = [dict[@"marginTop"] doubleValue];
  if (dict[@"marginBottom"]) style.marginBottom = [dict[@"marginBottom"] doubleValue];
  if (dict[@"marginLeft"]) style.marginLeft = [dict[@"marginLeft"] doubleValue];
  if (dict[@"marginRight"]) style.marginRight = [dict[@"marginRight"] doubleValue];
  if (dict[@"marginHorizontal"]) style.marginHorizontal = [dict[@"marginHorizontal"] doubleValue];
  if (dict[@"marginVertical"]) style.marginVertical = [dict[@"marginVertical"] doubleValue];

  // Padding
  if (dict[@"padding"]) style.padding = [dict[@"padding"] doubleValue];
  if (dict[@"paddingTop"]) style.paddingTop = [dict[@"paddingTop"] doubleValue];
  if (dict[@"paddingBottom"]) style.paddingBottom = [dict[@"paddingBottom"] doubleValue];
  if (dict[@"paddingLeft"]) style.paddingLeft = [dict[@"paddingLeft"] doubleValue];
  if (dict[@"paddingRight"]) style.paddingRight = [dict[@"paddingRight"] doubleValue];
  if (dict[@"paddingHorizontal"]) style.paddingHorizontal = [dict[@"paddingHorizontal"] doubleValue];
  if (dict[@"paddingVertical"]) style.paddingVertical = [dict[@"paddingVertical"] doubleValue];

  // Border widths
  if (dict[@"borderWidth"]) style.borderWidth = [dict[@"borderWidth"] doubleValue];
  if (dict[@"borderTopWidth"]) style.borderTopWidth = [dict[@"borderTopWidth"] doubleValue];
  if (dict[@"borderBottomWidth"]) style.borderBottomWidth = [dict[@"borderBottomWidth"] doubleValue];
  if (dict[@"borderLeftWidth"]) style.borderLeftWidth = [dict[@"borderLeftWidth"] doubleValue];
  if (dict[@"borderRightWidth"]) style.borderRightWidth = [dict[@"borderRightWidth"] doubleValue];

  // Border colors
  style.borderColor = [self colorFromValue:dict[@"borderColor"]];
  style.borderTopColor = [self colorFromValue:dict[@"borderTopColor"]];
  style.borderBottomColor = [self colorFromValue:dict[@"borderBottomColor"]];
  style.borderLeftColor = [self colorFromValue:dict[@"borderLeftColor"]];
  style.borderRightColor = [self colorFromValue:dict[@"borderRightColor"]];

  // Border radii
  if (dict[@"borderRadius"]) style.borderRadius = [dict[@"borderRadius"] doubleValue];
  if (dict[@"borderTopLeftRadius"]) style.borderTopLeftRadius = [dict[@"borderTopLeftRadius"] doubleValue];
  if (dict[@"borderTopRightRadius"]) style.borderTopRightRadius = [dict[@"borderTopRightRadius"] doubleValue];
  if (dict[@"borderBottomLeftRadius"]) style.borderBottomLeftRadius = [dict[@"borderBottomLeftRadius"] doubleValue];
  if (dict[@"borderBottomRightRadius"]) style.borderBottomRightRadius = [dict[@"borderBottomRightRadius"] doubleValue];

  if (dict[@"borderStyle"]) style.borderStyle = dict[@"borderStyle"];
  if (dict[@"borderCurve"]) style.borderCurve = dict[@"borderCurve"];

  return style;
}

+ (UIColor *)colorFromValue:(id)value {
  if (!value || [value isKindOfClass:[NSNull class]]) return nil;

  // Delegate to React Native's own color converter. It handles
  // every shape processColor can emit:
  //   - NSNumber  : argb int from hex / rgb() / named strings
  //   - NSString  : hex / named / rgb(a) / hsl(a) fallback
  //   - NSDictionary with `semantic` key : PlatformColor('name')
  //     resolves via `colorNamed:` and iOS system color accessors
  //     like +labelColor, +systemRedColor, etc.
  //   - NSDictionary with `dynamic` key  : DynamicColorIOS({ light,
  //     dark, … }) becomes a UIColor that resolves per trait
  //     collection at draw time.
  // Rolling our own hex parser here missed both PlatformColor
  // dicts and anything beyond 6-char hex.
  return [RCTConvert UIColor:value];
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
