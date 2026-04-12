#import <Foundation/Foundation.h>

@class FormattingStore;

NS_ASSUME_NONNULL_BEGIN

@interface MarkdownSerializer : NSObject

/// Converts plain text + formatting ranges back to a markdown string.
+ (NSString *)serializePlainText:(NSString *)text
                       withStore:(FormattingStore *)store;

@end

NS_ASSUME_NONNULL_END
