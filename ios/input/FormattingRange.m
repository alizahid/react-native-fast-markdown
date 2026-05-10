#import "FormattingRange.h"

@implementation FormattingRange

+ (instancetype)rangeWithType:(FormattingType)type range:(NSRange)range {
  return [self rangeWithType:type range:range url:nil];
}

+ (instancetype)rangeWithType:(FormattingType)type
                        range:(NSRange)range
                          url:(NSString *)url {
  FormattingRange *r = [FormattingRange new];
  r.type = type;
  r.range = range;
  r.url = url;
  r.listStart = 1;
  return r;
}

+ (instancetype)mentionRangeWithTagName:(NSString *)tagName
                               tagProps:(NSDictionary<NSString *, NSString *> *)tagProps
                                  range:(NSRange)range {
  FormattingRange *r = [self rangeWithType:FormattingTypeMention range:range];
  r.tagName = tagName;
  r.tagProps = tagProps;
  return r;
}

- (id)copyWithZone:(NSZone *)zone {
  FormattingRange *copy = [FormattingRange new];
  copy.type = _type;
  copy.range = _range;
  copy.url = [_url copy];
  copy.autolink = _autolink;
  copy.tagName = [_tagName copy];
  copy.tagProps = [_tagProps copy];
  copy.codeLanguage = [_codeLanguage copy];
  copy.listStart = _listStart;
  return copy;
}

+ (BOOL)isInlineType:(FormattingType)type {
  switch (type) {
  case FormattingTypeBold:
  case FormattingTypeItalic:
  case FormattingTypeStrikethrough:
  case FormattingTypeCode:
  case FormattingTypeLink:
  case FormattingTypeSpoiler:
  case FormattingTypeSuperscript:
  case FormattingTypeMention:
    return YES;
  default:
    return NO;
  }
}

+ (BOOL)isBlockType:(FormattingType)type {
  return ![self isInlineType:type];
}

+ (BOOL)isHeadingType:(FormattingType)type {
  return type >= FormattingTypeHeading1 && type <= FormattingTypeHeading6;
}

+ (NSInteger)headingLevelForType:(FormattingType)type {
  if (![self isHeadingType:type]) return 0;
  return (type - FormattingTypeHeading1) + 1;
}

+ (FormattingType)headingTypeForLevel:(NSInteger)level {
  if (level < 1) level = 1;
  if (level > 6) level = 6;
  return (FormattingType)(FormattingTypeHeading1 + level - 1);
}

@end
