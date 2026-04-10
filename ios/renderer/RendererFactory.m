#import "RendererFactory.h"
#import "TextRenderer.h"
#import "ParagraphRenderer.h"
#import "HeadingRenderer.h"
#import "StrongRenderer.h"
#import "EmphasisRenderer.h"
#import "CodeRenderer.h"
#import "CodeBlockRenderer.h"
#import "LinkRenderer.h"
#import "ListRenderer.h"
#import "ListItemRenderer.h"
#import "BlockquoteRenderer.h"
#import "StrikethroughRenderer.h"
#import "UnderlineRenderer.h"
#import "ThematicBreakRenderer.h"
#import "ImageRenderer.h"
#import "TableRenderer.h"
#import "CustomTagRenderer.h"

@implementation RendererFactory

static NSDictionary<NSNumber *, id<NodeRenderer>> *_renderers;

+ (void)initialize {
  if (self == [RendererFactory class]) {
    _renderers = @{
      @(MDNodeTypeText) : [TextRenderer new],
      @(MDNodeTypeSoftBreak) : [TextRenderer new],
      @(MDNodeTypeLineBreak) : [TextRenderer new],
      @(MDNodeTypeParagraph) : [ParagraphRenderer new],
      @(MDNodeTypeHeading) : [HeadingRenderer new],
      @(MDNodeTypeStrong) : [StrongRenderer new],
      @(MDNodeTypeEmphasis) : [EmphasisRenderer new],
      @(MDNodeTypeCode) : [CodeRenderer new],
      @(MDNodeTypeCodeBlock) : [CodeBlockRenderer new],
      @(MDNodeTypeLink) : [LinkRenderer new],
      @(MDNodeTypeList) : [ListRenderer new],
      @(MDNodeTypeListItem) : [ListItemRenderer new],
      @(MDNodeTypeBlockquote) : [BlockquoteRenderer new],
      @(MDNodeTypeStrikethrough) : [StrikethroughRenderer new],
      @(MDNodeTypeUnderline) : [UnderlineRenderer new],
      @(MDNodeTypeThematicBreak) : [ThematicBreakRenderer new],
      @(MDNodeTypeImage) : [ImageRenderer new],
      @(MDNodeTypeTable) : [TableRenderer new],
      @(MDNodeTypeTableHead) : [TableRenderer new],
      @(MDNodeTypeTableBody) : [TableRenderer new],
      @(MDNodeTypeTableRow) : [TableRenderer new],
      @(MDNodeTypeTableCell) : [TableRenderer new],
      @(MDNodeTypeCustomTag) : [CustomTagRenderer new],
      @(MDNodeTypeDocument) : [ParagraphRenderer new],
    };
  }
}

+ (nullable id<NodeRenderer>)rendererForNode:(ASTNodeWrapper *)node {
  return _renderers[@(node.nodeType)];
}

@end
