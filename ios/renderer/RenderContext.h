#import <UIKit/UIKit.h>

@class StyleConfig;
@class ASTNodeWrapper;

NS_ASSUME_NONNULL_BEGIN

typedef void (^LinkPressHandler)(NSString *url, NSString *title);
typedef void (^MentionPressHandler)(NSString *user);
typedef void (^TaskListItemPressHandler)(NSInteger index, BOOL checked);

@interface RenderContext : NSObject

@property (nonatomic, strong) StyleConfig *styleConfig;
@property (nonatomic, strong, nullable) NSSet<NSString *> *customTags;

// Callbacks
@property (nonatomic, copy, nullable) LinkPressHandler onLinkPress;
@property (nonatomic, copy, nullable) LinkPressHandler onLinkLongPress;
@property (nonatomic, copy, nullable) MentionPressHandler onMentionPress;
@property (nonatomic, copy, nullable) TaskListItemPressHandler onTaskListItemPress;

// Rendering state
@property (nonatomic, assign) NSInteger listDepth;
@property (nonatomic, assign) NSInteger orderedListIndex;
@property (nonatomic, assign) BOOL isInsideBlockquote;
@property (nonatomic, assign) BOOL isInsideCodeBlock;
@property (nonatomic, assign) NSInteger taskListIndex;

// Style stack for nested inline styles
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSAttributedStringKey, id> *> *attributeStack;

- (void)pushAttributes:(NSDictionary<NSAttributedStringKey, id> *)attrs;
- (void)popAttributes;
- (NSDictionary<NSAttributedStringKey, id> *)currentAttributes;

- (void)renderChildren:(ASTNodeWrapper *)node
                  into:(NSMutableAttributedString *)output;

/// Renders a top-level block node to an attributed string using a
/// fresh RenderContext, trimming trailing newlines. Thread-safe.
+ (NSAttributedString *)renderNodeToAttributedString:(ASTNodeWrapper *)node
                                         styleConfig:(StyleConfig *)styleConfig
                                          customTags:
                                              (NSArray<NSString *> *)customTags;

/// Renders a single list item, preserving the ordered index / depth
/// so bullets render correctly. Thread-safe.
+ (NSAttributedString *)renderListItemContent:(ASTNodeWrapper *)item
                                 orderedIndex:(NSInteger)orderedIndex
                                  styleConfig:(StyleConfig *)styleConfig
                                   customTags:(NSArray<NSString *> *)customTags;

@end

NS_ASSUME_NONNULL_END
