#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FormattingType) {
  FormattingTypeBold,
  FormattingTypeItalic,
  FormattingTypeStrikethrough,
  FormattingTypeCode,
  FormattingTypeCodeBlock,
  FormattingTypeLink,
  FormattingTypeHeading1,
  FormattingTypeHeading2,
  FormattingTypeHeading3,
  FormattingTypeHeading4,
  FormattingTypeHeading5,
  FormattingTypeHeading6,
  FormattingTypeBlockquote,
  FormattingTypeOrderedList,
  FormattingTypeUnorderedList,
};

@interface FormattingRange : NSObject <NSCopying>

@property (nonatomic) FormattingType type;
@property (nonatomic) NSRange range;
@property (nonatomic, copy, nullable) NSString *url;

+ (instancetype)rangeWithType:(FormattingType)type range:(NSRange)range;
+ (instancetype)rangeWithType:(FormattingType)type
                        range:(NSRange)range
                          url:(nullable NSString *)url;

+ (BOOL)isInlineType:(FormattingType)type;
+ (BOOL)isBlockType:(FormattingType)type;
+ (BOOL)isHeadingType:(FormattingType)type;
+ (NSInteger)headingLevelForType:(FormattingType)type;
+ (FormattingType)headingTypeForLevel:(NSInteger)level;

@end

NS_ASSUME_NONNULL_END
