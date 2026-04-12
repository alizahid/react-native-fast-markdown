#import "InputParser.h"
#import "FormattingRange.h"
#import "FormattingStore.h"

#import "ASTNodeWrapper.h"
#import "MarkdownParser.hpp"

@implementation InputParserResult
@end

// Context passed through the recursive AST walk.
@interface _IPWalkContext : NSObject
@property (nonatomic, strong) NSMutableString *text;
@property (nonatomic, strong) NSMutableArray<FormattingRange *> *ranges;
@property (nonatomic) BOOL needsNewline;
@end

@implementation _IPWalkContext
@end

@implementation InputParser

+ (InputParserResult *)parseMarkdown:(NSString *)markdown {
  InputParserResult *result = [InputParserResult new];
  result.store = [FormattingStore new];

  if (markdown.length == 0) {
    result.plainText = @"";
    return result;
  }

  markdown::ParseOptions options;
  options.enableTables = false;
  options.enableStrikethrough = true;
  options.enableTaskLists = false;
  options.enableAutolinks = true;
  options.customTags.insert("Spoiler");
  options.customTags.insert("Superscript");

  std::string mdStr([markdown UTF8String]);
  markdown::ASTNode ast = markdown::MarkdownParser::parse(mdStr, options);
  ASTNodeWrapper *root = [[ASTNodeWrapper alloc] initWithOpaqueNode:&ast];

  _IPWalkContext *ctx = [_IPWalkContext new];
  ctx.text = [NSMutableString new];
  ctx.ranges = [NSMutableArray new];
  ctx.needsNewline = NO;

  [self walkNode:root context:ctx blockType:nil linkUrl:nil];

  // Trim trailing newlines
  while (ctx.text.length > 0 &&
         [ctx.text characterAtIndex:ctx.text.length - 1] == '\n') {
    [ctx.text deleteCharactersInRange:NSMakeRange(ctx.text.length - 1, 1)];
  }

  result.plainText = [ctx.text copy];
  [result.store replaceAllRanges:ctx.ranges];
  return result;
}

+ (void)walkNode:(ASTNodeWrapper *)node
         context:(_IPWalkContext *)ctx
       blockType:(NSNumber *)blockType
         linkUrl:(NSString *)linkUrl {

  switch (node.nodeType) {

  case MDNodeTypeDocument: {
    for (ASTNodeWrapper *child in node.children) {
      [self walkNode:child context:ctx blockType:nil linkUrl:nil];
    }
    break;
  }

  case MDNodeTypeParagraph: {
    if (ctx.needsNewline) {
      [ctx.text appendString:@"\n\n"];
    }
    NSUInteger start = ctx.text.length;
    for (ASTNodeWrapper *child in node.children) {
      [self walkNode:child context:ctx blockType:blockType linkUrl:linkUrl];
    }
    // If we're inside a block (blockquote, list), the block range
    // is created by the parent — we just emit text.
    ctx.needsNewline = YES;
    break;
  }

  case MDNodeTypeHeading: {
    if (ctx.needsNewline) {
      [ctx.text appendString:@"\n\n"];
    }
    NSUInteger start = ctx.text.length;
    FormattingType hType =
        [FormattingRange headingTypeForLevel:node.headingLevel];
    for (ASTNodeWrapper *child in node.children) {
      [self walkNode:child context:ctx blockType:nil linkUrl:nil];
    }
    NSUInteger len = ctx.text.length - start;
    if (len > 0) {
      [ctx.ranges addObject:[FormattingRange
                                rangeWithType:hType
                                        range:NSMakeRange(start, len)]];
    }
    ctx.needsNewline = YES;
    break;
  }

  case MDNodeTypeBlockquote: {
    if (ctx.needsNewline) {
      [ctx.text appendString:@"\n\n"];
    }
    NSUInteger start = ctx.text.length;
    for (ASTNodeWrapper *child in node.children) {
      [self walkNode:child
             context:ctx
           blockType:@(FormattingTypeBlockquote)
             linkUrl:nil];
    }
    NSUInteger len = ctx.text.length - start;
    if (len > 0) {
      [ctx.ranges addObject:[FormattingRange
                                rangeWithType:FormattingTypeBlockquote
                                        range:NSMakeRange(start, len)]];
    }
    ctx.needsNewline = YES;
    break;
  }

  case MDNodeTypeList: {
    NSInteger idx = 0;
    for (ASTNodeWrapper *item in node.children) {
      if (ctx.needsNewline) {
        [ctx.text appendString:@"\n"];
      }

      FormattingType listType = node.isOrderedList
                                    ? FormattingTypeOrderedList
                                    : FormattingTypeUnorderedList;

      // Prepend bullet / number
      NSString *bullet;
      if (node.isOrderedList) {
        bullet = [NSString
            stringWithFormat:@"%ld. ", (long)(node.listStart + idx)];
      } else {
        bullet = @"\u2022 ";
      }
      [ctx.text appendString:bullet];

      NSUInteger itemStart = ctx.text.length - bullet.length;

      // Walk list item children (skip the ListItem wrapper)
      for (ASTNodeWrapper *child in item.children) {
        [self walkNode:child
               context:ctx
             blockType:@(listType)
               linkUrl:nil];
      }

      NSUInteger itemLen = ctx.text.length - itemStart;
      if (itemLen > 0) {
        [ctx.ranges addObject:[FormattingRange
                                  rangeWithType:listType
                                          range:NSMakeRange(itemStart,
                                                             itemLen)]];
      }

      ctx.needsNewline = YES;
      idx++;
    }
    break;
  }

  case MDNodeTypeCodeBlock: {
    if (ctx.needsNewline) {
      [ctx.text appendString:@"\n\n"];
    }
    NSUInteger start = ctx.text.length;
    // Code block content is in the children (text nodes)
    for (ASTNodeWrapper *child in node.children) {
      [self walkNode:child context:ctx blockType:nil linkUrl:nil];
    }
    // Trim trailing newline inside code block
    if (ctx.text.length > start &&
        [ctx.text characterAtIndex:ctx.text.length - 1] == '\n') {
      [ctx.text deleteCharactersInRange:NSMakeRange(ctx.text.length - 1, 1)];
    }
    NSUInteger len = ctx.text.length - start;
    if (len > 0) {
      [ctx.ranges addObject:[FormattingRange
                                rangeWithType:FormattingTypeCodeBlock
                                        range:NSMakeRange(start, len)]];
    }
    ctx.needsNewline = YES;
    break;
  }

  case MDNodeTypeThematicBreak: {
    if (ctx.needsNewline) {
      [ctx.text appendString:@"\n\n"];
    }
    [ctx.text appendString:@"\u2500\u2500\u2500\u2500\u2500\u2500\u2500"];
    ctx.needsNewline = YES;
    break;
  }

  // ---- Inline ----

  case MDNodeTypeStrong: {
    NSUInteger start = ctx.text.length;
    for (ASTNodeWrapper *child in node.children) {
      [self walkNode:child context:ctx blockType:blockType linkUrl:linkUrl];
    }
    NSUInteger len = ctx.text.length - start;
    if (len > 0) {
      [ctx.ranges addObject:[FormattingRange
                                rangeWithType:FormattingTypeBold
                                        range:NSMakeRange(start, len)]];
    }
    break;
  }

  case MDNodeTypeEmphasis: {
    NSUInteger start = ctx.text.length;
    for (ASTNodeWrapper *child in node.children) {
      [self walkNode:child context:ctx blockType:blockType linkUrl:linkUrl];
    }
    NSUInteger len = ctx.text.length - start;
    if (len > 0) {
      [ctx.ranges addObject:[FormattingRange
                                rangeWithType:FormattingTypeItalic
                                        range:NSMakeRange(start, len)]];
    }
    break;
  }

  case MDNodeTypeStrikethrough: {
    NSUInteger start = ctx.text.length;
    for (ASTNodeWrapper *child in node.children) {
      [self walkNode:child context:ctx blockType:blockType linkUrl:linkUrl];
    }
    NSUInteger len = ctx.text.length - start;
    if (len > 0) {
      [ctx.ranges addObject:[FormattingRange
                                rangeWithType:FormattingTypeStrikethrough
                                        range:NSMakeRange(start, len)]];
    }
    break;
  }

  case MDNodeTypeCode: {
    NSUInteger start = ctx.text.length;
    [ctx.text appendString:node.content ?: @""];
    NSUInteger len = ctx.text.length - start;
    if (len > 0) {
      [ctx.ranges addObject:[FormattingRange
                                rangeWithType:FormattingTypeCode
                                        range:NSMakeRange(start, len)]];
    }
    break;
  }

  case MDNodeTypeLink: {
    NSUInteger start = ctx.text.length;
    for (ASTNodeWrapper *child in node.children) {
      [self walkNode:child context:ctx blockType:blockType linkUrl:node.linkUrl];
    }
    NSUInteger len = ctx.text.length - start;
    if (len > 0) {
      [ctx.ranges addObject:[FormattingRange
                                rangeWithType:FormattingTypeLink
                                        range:NSMakeRange(start, len)
                                          url:node.linkUrl]];
    }
    break;
  }

  case MDNodeTypeText: {
    [ctx.text appendString:node.content ?: @""];
    break;
  }

  case MDNodeTypeSoftBreak: {
    [ctx.text appendString:@" "];
    break;
  }

  case MDNodeTypeLineBreak: {
    [ctx.text appendString:@"\n"];
    break;
  }

  default: {
    for (ASTNodeWrapper *child in node.children) {
      [self walkNode:child context:ctx blockType:blockType linkUrl:linkUrl];
    }
    break;
  }
  }
}

@end
