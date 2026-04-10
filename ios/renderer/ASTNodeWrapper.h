#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Obj-C enum mirroring C++ NodeType
typedef NS_ENUM(NSInteger, MDNodeType) {
  MDNodeTypeDocument,
  MDNodeTypeParagraph,
  MDNodeTypeHeading,
  MDNodeTypeBlockquote,
  MDNodeTypeList,
  MDNodeTypeListItem,
  MDNodeTypeCodeBlock,
  MDNodeTypeThematicBreak,
  MDNodeTypeTable,
  MDNodeTypeTableHead,
  MDNodeTypeTableBody,
  MDNodeTypeTableRow,
  MDNodeTypeTableCell,
  MDNodeTypeHtmlBlock,
  MDNodeTypeText,
  MDNodeTypeSoftBreak,
  MDNodeTypeLineBreak,
  MDNodeTypeCode,
  MDNodeTypeEmphasis,
  MDNodeTypeStrong,
  MDNodeTypeStrikethrough,
  MDNodeTypeLink,
  MDNodeTypeImage,
  MDNodeTypeHtmlInline,
  MDNodeTypeUnderline,
  MDNodeTypeCustomTag,
};

typedef NS_ENUM(NSInteger, MDTableAlign) {
  MDTableAlignDefault,
  MDTableAlignLeft,
  MDTableAlignCenter,
  MDTableAlignRight,
};

@interface ASTNodeWrapper : NSObject

@property (nonatomic, readonly) MDNodeType nodeType;
@property (nonatomic, readonly, copy) NSString *content;

// Block attributes
@property (nonatomic, readonly) NSInteger headingLevel;
@property (nonatomic, readonly) BOOL isOrderedList;
@property (nonatomic, readonly) NSInteger listStart;
@property (nonatomic, readonly) BOOL listTight;
@property (nonatomic, readonly) BOOL isTaskItem;
@property (nonatomic, readonly) BOOL taskChecked;
@property (nonatomic, readonly, copy) NSString *codeLanguage;
@property (nonatomic, readonly) MDTableAlign tableAlign;
@property (nonatomic, readonly) NSInteger tableColumnCount;

// Inline attributes
@property (nonatomic, readonly, copy) NSString *linkUrl;
@property (nonatomic, readonly, copy) NSString *linkTitle;
@property (nonatomic, readonly, copy) NSString *imageSrc;
@property (nonatomic, readonly, copy) NSString *imageTitle;
@property (nonatomic, readonly) BOOL isAutolink;

// Custom tag
@property (nonatomic, readonly, copy) NSString *tagName;
@property (nonatomic, readonly, copy) NSDictionary<NSString *, NSString *> *tagProps;

// Children
@property (nonatomic, readonly) NSArray<ASTNodeWrapper *> *children;

// Internal: opaque pointer to C++ ASTNode
- (instancetype)initWithOpaqueNode:(const void *)node;

@end

NS_ASSUME_NONNULL_END
