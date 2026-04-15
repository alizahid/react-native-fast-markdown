#import "ASTNodeWrapper.h"
#import "ASTNode.hpp"

@implementation ASTNodeWrapper {
  const markdown::ASTNode *_cppNode;
  NSArray<ASTNodeWrapper *> *_cachedChildren;
  NSDictionary<NSString *, NSString *> *_cachedTagProps;
}

- (instancetype)initWithOpaqueNode:(const void *)node {
  if (!node) return nil;
  self = [super init];
  if (self) {
    _cppNode = static_cast<const markdown::ASTNode *>(node);
  }
  return self;
}

- (MDNodeType)nodeType {
  switch (_cppNode->type) {
    case markdown::NodeType::Document:       return MDNodeTypeDocument;
    case markdown::NodeType::Paragraph:      return MDNodeTypeParagraph;
    case markdown::NodeType::Heading:        return MDNodeTypeHeading;
    case markdown::NodeType::Blockquote:     return MDNodeTypeBlockquote;
    case markdown::NodeType::List:           return MDNodeTypeList;
    case markdown::NodeType::ListItem:       return MDNodeTypeListItem;
    case markdown::NodeType::CodeBlock:      return MDNodeTypeCodeBlock;
    case markdown::NodeType::ThematicBreak:  return MDNodeTypeThematicBreak;
    case markdown::NodeType::Table:          return MDNodeTypeTable;
    case markdown::NodeType::TableHead:      return MDNodeTypeTableHead;
    case markdown::NodeType::TableBody:      return MDNodeTypeTableBody;
    case markdown::NodeType::TableRow:       return MDNodeTypeTableRow;
    case markdown::NodeType::TableCell:      return MDNodeTypeTableCell;
    case markdown::NodeType::HtmlBlock:      return MDNodeTypeHtmlBlock;
    case markdown::NodeType::Text:           return MDNodeTypeText;
    case markdown::NodeType::SoftBreak:      return MDNodeTypeSoftBreak;
    case markdown::NodeType::LineBreak:      return MDNodeTypeLineBreak;
    case markdown::NodeType::Code:           return MDNodeTypeCode;
    case markdown::NodeType::Emphasis:       return MDNodeTypeEmphasis;
    case markdown::NodeType::Strong:         return MDNodeTypeStrong;
    case markdown::NodeType::Strikethrough:  return MDNodeTypeStrikethrough;
    case markdown::NodeType::Link:           return MDNodeTypeLink;
    case markdown::NodeType::Image:          return MDNodeTypeImage;
    case markdown::NodeType::HtmlInline:     return MDNodeTypeHtmlInline;
    case markdown::NodeType::CustomTag:      return MDNodeTypeCustomTag;
  }
}

- (NSString *)content {
  return [NSString stringWithUTF8String:_cppNode->content.c_str()];
}

- (NSInteger)headingLevel { return _cppNode->headingLevel; }

- (BOOL)isOrderedList {
  return _cppNode->listType == markdown::ListType::Ordered;
}

- (NSInteger)listStart { return _cppNode->listStart; }
- (BOOL)listTight { return _cppNode->listTight; }
- (BOOL)isTaskItem { return _cppNode->isTaskItem; }
- (BOOL)taskChecked { return _cppNode->taskChecked; }

- (NSString *)codeLanguage {
  return [NSString stringWithUTF8String:_cppNode->codeLanguage.c_str()];
}

- (MDTableAlign)tableAlign {
  switch (_cppNode->tableAlign) {
    case markdown::TableAlign::Left:    return MDTableAlignLeft;
    case markdown::TableAlign::Center:  return MDTableAlignCenter;
    case markdown::TableAlign::Right:   return MDTableAlignRight;
    default:                            return MDTableAlignDefault;
  }
}

- (NSInteger)tableColumnCount { return _cppNode->tableColumnCount; }

- (NSString *)linkUrl {
  return [NSString stringWithUTF8String:_cppNode->linkUrl.c_str()];
}

- (NSString *)linkTitle {
  return [NSString stringWithUTF8String:_cppNode->linkTitle.c_str()];
}

- (NSString *)imageSrc {
  return [NSString stringWithUTF8String:_cppNode->imageSrc.c_str()];
}

- (NSString *)imageTitle {
  return [NSString stringWithUTF8String:_cppNode->imageTitle.c_str()];
}

- (BOOL)isAutolink { return _cppNode->isAutolink; }

- (NSString *)tagName {
  return [NSString stringWithUTF8String:_cppNode->tagName.c_str()];
}

- (NSDictionary<NSString *, NSString *> *)tagProps {
  if (_cachedTagProps) return _cachedTagProps;

  NSMutableDictionary *props = [NSMutableDictionary new];
  for (const auto &pair : _cppNode->tagProps) {
    NSString *key = [NSString stringWithUTF8String:pair.first.c_str()];
    NSString *value = [NSString stringWithUTF8String:pair.second.c_str()];
    props[key] = value;
  }
  _cachedTagProps = [props copy];
  return _cachedTagProps;
}

- (NSArray<ASTNodeWrapper *> *)children {
  if (_cachedChildren) return _cachedChildren;

  NSMutableArray *wrappers =
      [NSMutableArray arrayWithCapacity:_cppNode->children.size()];
  for (const auto &child : _cppNode->children) {
    ASTNodeWrapper *wrapper =
        [[ASTNodeWrapper alloc] initWithOpaqueNode:&child];
    [wrappers addObject:wrapper];
  }
  _cachedChildren = [wrappers copy];
  return _cachedChildren;
}

@end
