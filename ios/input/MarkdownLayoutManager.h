#import <UIKit/UIKit.h>

@class StyleConfig;

NS_ASSUME_NONNULL_BEGIN

/// Custom attribute key used to tag paragraphs as belonging to a
/// block type. The value is an NSString: @"codeBlock" or
/// @"blockquote". UITextView propagates paragraph-level
/// attributes on Enter automatically, so block continuation is
/// handled natively.
extern NSString *const MDBlockTypeAttributeName;

extern NSString *const MDBlockTypeCodeBlock;
extern NSString *const MDBlockTypeBlockquote;

@interface MarkdownLayoutManager : NSLayoutManager

@property (nonatomic, strong, nullable) StyleConfig *styleConfig;

@end

NS_ASSUME_NONNULL_END
