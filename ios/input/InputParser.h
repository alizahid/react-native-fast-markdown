#import <Foundation/Foundation.h>

@class FormattingStore;

NS_ASSUME_NONNULL_BEGIN

@interface InputParserResult : NSObject
@property (nonatomic, copy) NSString *plainText;
@property (nonatomic, strong) FormattingStore *store;
@end

@interface InputParser : NSObject

/// Parses a markdown string into plain text (syntax markers stripped)
/// and a FormattingStore holding the formatting ranges.
+ (InputParserResult *)parseMarkdown:(NSString *)markdown;

@end

NS_ASSUME_NONNULL_END
