#import "MarkdownMeasurer.h"

#import "ASTNodeWrapper.h"
#import "MarkdownImageSizeCache.h"
#import "MarkdownImageView.h"
#import "MarkdownParser.hpp"
#import "MarkdownTableView.h"
#import "RenderContext.h"
#import "StyleAttributes.h"
#import "StyleConfig.h"

// Must match kDefaultImageHeight in MarkdownView.mm — both the
// runtime build and the shadow-thread measurement need to reserve
// the same height for a block image before its URL has loaded.
static const CGFloat kMeasurerDefaultImageHeight = 200.0;

static NSCache<NSString *, NSValue *> *sMeasureCache(void) {
  static dispatch_once_t once;
  static NSCache<NSString *, NSValue *> *cache;
  dispatch_once(&once, ^{
    cache = [[NSCache alloc] init];
    cache.countLimit = 512;
  });
  return cache;
}

static NSString *MakePropImageSizesKey(
    NSDictionary<NSString *, NSValue *> *propImageSizes) {
  if (propImageSizes.count == 0) return @"";
  // Sort URLs for a deterministic key so two prop maps with the
  // same contents (regardless of insertion order) hash identically.
  NSArray<NSString *> *urls =
      [propImageSizes.allKeys sortedArrayUsingSelector:@selector(compare:)];
  NSMutableString *key = [NSMutableString new];
  for (NSString *url in urls) {
    CGSize size = [propImageSizes[url] CGSizeValue];
    [key appendFormat:@"%@:%.1fx%.1f|", url, size.width, size.height];
  }
  return key;
}

static NSString *MakeCacheKey(NSString *markdown,
                              NSString *stylesJSON,
                              NSArray<NSString *> *customTags,
                              NSDictionary<NSString *, NSValue *> *propImageSizes,
                              CGFloat width) {
  NSString *tagsKey = [customTags componentsJoinedByString:@","] ?: @"";
  NSString *imgKey = MakePropImageSizesKey(propImageSizes);
  return [NSString stringWithFormat:@"%.1f|%@|%@|%@|%@",
                                    width,
                                    tagsKey,
                                    imgKey,
                                    stylesJSON ?: @"",
                                    markdown ?: @""];
}

static MarkdownElementStyle *BlockStyleForNodeType(
    MDNodeType type,
    NSInteger headingLevel,
    StyleConfig *cfg) {
  switch (type) {
    case MDNodeTypeParagraph:
      return cfg.paragraph;
    case MDNodeTypeHeading:
      return [cfg styleForHeadingLevel:headingLevel];
    case MDNodeTypeCodeBlock:
      return cfg.codeBlock;
    case MDNodeTypeBlockquote:
      return cfg.blockquote;
    default:
      return nil;
  }
}

/// Mirror of MarkdownView.imageOnlyParagraphChild: — returns the
/// single Image child of a top-level paragraph whose only
/// non-whitespace content is an image. Keeping this in sync with
/// the runtime path is how the shadow-thread measurement agrees
/// with the built view's actual height.
static ASTNodeWrapper *ImageOnlyParagraphChild(ASTNodeWrapper *node) {
  if (node.nodeType != MDNodeTypeParagraph) return nil;

  ASTNodeWrapper *imageChild = nil;
  NSCharacterSet *whitespace =
      [NSCharacterSet whitespaceAndNewlineCharacterSet];
  for (ASTNodeWrapper *child in node.children) {
    if (child.nodeType == MDNodeTypeImage) {
      if (imageChild) return nil;
      imageChild = child;
    } else if (child.nodeType == MDNodeTypeText) {
      NSString *trimmed =
          [child.content stringByTrimmingCharactersInSet:whitespace];
      if (trimmed.length > 0) return nil;
    } else if (child.nodeType == MDNodeTypeSoftBreak ||
               child.nodeType == MDNodeTypeLineBreak) {
      continue;
    } else {
      return nil;
    }
  }
  return imageChild;
}

/// Returns the total box size (content + padding + borders + margins)
/// for a styled block. Mirrors MarkdownBlockView.sizeThatFits so the
/// shadow-thread measurement matches the rendered view exactly.
static CGSize SizeForBlockStyle(MarkdownElementStyle *style,
                                CGSize contentSize) {
  UIEdgeInsets margin = [style resolvedMarginInsets];
  UIEdgeInsets padding = [style resolvedPaddingInsets];
  UIEdgeInsets borders = [style resolvedBorderWidths];

  CGFloat marginW = margin.left + margin.right;
  CGFloat marginH = margin.top + margin.bottom;
  CGFloat extraW = padding.left + padding.right + borders.left + borders.right;
  CGFloat extraH = padding.top + padding.bottom + borders.top + borders.bottom;

  CGFloat borderBoxW =
      style.width > 0 ? style.width : contentSize.width + extraW;
  CGFloat borderBoxH =
      style.height > 0 ? style.height : contentSize.height + extraH;

  return CGSizeMake(borderBoxW + marginW, borderBoxH + marginH);
}

/// Measures an NSAttributedString for a given max width.
static CGSize MeasureAttributedString(NSAttributedString *text,
                                      CGFloat maxWidth) {
  if (text.length == 0 || maxWidth <= 0) return CGSizeZero;

  CGRect rect = [text
      boundingRectWithSize:CGSizeMake(maxWidth, CGFLOAT_MAX)
                   options:NSStringDrawingUsesLineFragmentOrigin |
                           NSStringDrawingUsesFontLeading
                   context:nil];
  return CGSizeMake(ceil(rect.size.width), ceil(rect.size.height));
}

/// Height of a single top-level block for an available inner width.
/// inheritedAttrs carries text styling cascaded down from parent
/// blocks (e.g. a blockquote's fontStyle applied to its child
/// paragraphs). Pass nil at the root.
static CGFloat MeasureSegmentHeight(ASTNodeWrapper *node,
                                    StyleConfig *styleConfig,
                                    NSArray<NSString *> *customTags,
                                    NSDictionary<NSString *, NSValue *> *propImageSizes,
                                    CGFloat innerWidth,
                                    NSDictionary *inheritedAttrs) {
  MDNodeType type = node.nodeType;

  // Block image — paragraphs that contain exactly one image (with
  // only whitespace around it) get a dedicated image segment on the
  // runtime side, so the measurer needs to reserve the same height.
  //
  // Prefer the per-view prop size (authoritative, supplied by the
  // caller via the `images` prop). Fall back to the discovered
  // shared cache populated by completed downloads. Finally fall
  // back to the style's width/height override or the default
  // reservation. When a natural size is known the content box
  // matches it exactly (scaled down proportionally if wider than
  // the available width, never scaled up) so borders and corner
  // radii applied via `image: { ... }` wrap the image tightly
  // without any breathing-room inset.
  if (ASTNodeWrapper *imageChild = ImageOnlyParagraphChild(node)) {
    MarkdownElementStyle *imageStyle = styleConfig.image;

    UIEdgeInsets padding = [imageStyle resolvedPaddingInsets];
    UIEdgeInsets borders = [imageStyle resolvedBorderWidths];
    UIEdgeInsets margin = [imageStyle resolvedMarginInsets];
    CGFloat contentWidth = innerWidth - padding.left - padding.right -
                           borders.left - borders.right - margin.left -
                           margin.right;

    NSString *urlKey = imageChild.imageSrc ?: @"";
    CGSize natural = CGSizeZero;
    NSValue *propValue = urlKey.length > 0 ? propImageSizes[urlKey] : nil;
    if (propValue) {
      natural = [propValue CGSizeValue];
    } else {
      natural = [[MarkdownImageSizeCache sharedCache]
          sizeForURLString:urlKey];
    }

    CGSize contentSize;
    if (natural.width > 0 && natural.height > 0 && contentWidth > 0) {
      // Delegate to the same sizing helper MarkdownImageView uses
      // so the reserved block height matches the rendered one
      // exactly, including maxWidth / maxHeight / objectFit.
      contentSize =
          [MarkdownImageView blockSizeForNaturalSize:natural
                                      availableWidth:contentWidth
                                            maxWidth:imageStyle.maxWidth
                                           maxHeight:imageStyle.maxHeight
                                           objectFit:imageStyle.objectFit];
    } else {
      CGFloat h = imageStyle.height > 0 ? imageStyle.height
                                         : kMeasurerDefaultImageHeight;
      contentSize = CGSizeMake(contentWidth, h);
    }

    CGSize framed = SizeForBlockStyle(imageStyle, contentSize);
    return framed.height;
  }

  if (type == MDNodeTypeThematicBreak) {
    MarkdownElementStyle *style = styleConfig.thematicBreak;
    CGSize framed = SizeForBlockStyle(style, CGSizeZero);
    return framed.height;
  }

  if (type == MDNodeTypeBlockquote) {
    MarkdownElementStyle *blockquoteStyle = styleConfig.blockquote;

    UIEdgeInsets margin = [blockquoteStyle resolvedMarginInsets];
    UIEdgeInsets padding = [blockquoteStyle resolvedPaddingInsets];
    UIEdgeInsets borders = [blockquoteStyle resolvedBorderWidths];
    CGFloat childInnerWidth = innerWidth - margin.left - margin.right -
                              padding.left - padding.right - borders.left -
                              borders.right;

    NSMutableDictionary *childAttrs =
        [(inheritedAttrs
              ?: [RenderContext baseAttributesFromStyleConfig:styleConfig])
            mutableCopy];
    [StyleAttributes applyStyle:blockquoteStyle toAttrs:childAttrs];
    NSDictionary *childAttrsFrozen = [childAttrs copy];

    CGFloat totalChildren = 0;
    NSInteger visibleChildren = 0;
    for (ASTNodeWrapper *child in node.children) {
      CGFloat h = MeasureSegmentHeight(child, styleConfig, customTags,
                                       propImageSizes, childInnerWidth,
                                       childAttrsFrozen);
      if (h > 0) {
        totalChildren += h;
        visibleChildren++;
      }
    }
    if (visibleChildren > 1) {
      totalChildren += blockquoteStyle.gap * (visibleChildren - 1);
    }

    CGSize bqSize = SizeForBlockStyle(blockquoteStyle,
                                      CGSizeMake(0, totalChildren));
    return bqSize.height;
  }

  if (type == MDNodeTypeList) {
    MarkdownElementStyle *listStyle = styleConfig.list;
    MarkdownElementStyle *itemStyle = styleConfig.listItem;

    UIEdgeInsets listMargin = [listStyle resolvedMarginInsets];
    UIEdgeInsets listPadding = [listStyle resolvedPaddingInsets];
    UIEdgeInsets listBorders = [listStyle resolvedBorderWidths];
    CGFloat itemWidth = innerWidth - listMargin.left - listMargin.right -
                        listPadding.left - listPadding.right - listBorders.left -
                        listBorders.right;

    UIEdgeInsets itemMargin = [itemStyle resolvedMarginInsets];
    UIEdgeInsets itemPadding = [itemStyle resolvedPaddingInsets];
    UIEdgeInsets itemBorders = [itemStyle resolvedBorderWidths];
    CGFloat itemContentWidth = itemWidth - itemMargin.left - itemMargin.right -
                               itemPadding.left - itemPadding.right -
                               itemBorders.left - itemBorders.right;

    BOOL isOrdered = node.isOrderedList;
    CGFloat totalItemsHeight = 0;
    NSInteger visibleItems = 0;
    NSInteger orderedIndex =
        isOrdered && node.listStart > 0 ? node.listStart : 1;

    NSInteger maxMarkerDigits = 0;
    if (isOrdered) {
      NSInteger itemCount = 0;
      for (ASTNodeWrapper *child in node.children) {
        if (child.nodeType == MDNodeTypeListItem) itemCount++;
      }
      NSInteger lastNumber = MAX(1, orderedIndex + itemCount - 1);
      maxMarkerDigits = 1;
      while (lastNumber >= 10) {
        maxMarkerDigits++;
        lastNumber /= 10;
      }
    }

    for (ASTNodeWrapper *child in node.children) {
      if (child.nodeType != MDNodeTypeListItem) continue;

      NSAttributedString *content =
          [RenderContext renderListItemContent:child
                                     isOrdered:isOrdered
                                  orderedIndex:orderedIndex
                               maxMarkerDigits:maxMarkerDigits
                                   styleConfig:styleConfig
                                    customTags:customTags
                                inheritedAttrs:inheritedAttrs];
      if (isOrdered) orderedIndex++;

      CGSize textSize = MeasureAttributedString(content, itemContentWidth);
      CGSize itemSize = SizeForBlockStyle(itemStyle, textSize);
      totalItemsHeight += itemSize.height;
      visibleItems++;
    }

    if (visibleItems > 1) {
      totalItemsHeight += listStyle.gap * (visibleItems - 1);
    }

    CGSize listSize =
        SizeForBlockStyle(listStyle, CGSizeMake(0, totalItemsHeight));
    return listSize.height;
  }

  if (type == MDNodeTypeTable) {
    // Tables share the full layout pipeline with the view build path,
    // so the measurement here matches the final rendered size exactly.
    MarkdownElementStyle *tableStyle = styleConfig.table;
    UIEdgeInsets wrapperMargin = [tableStyle resolvedMarginInsets];
    UIEdgeInsets wrapperPadding = [tableStyle resolvedPaddingInsets];
    UIEdgeInsets wrapperBorders = [tableStyle resolvedBorderWidths];
    CGFloat tableInnerWidth =
        innerWidth - wrapperMargin.left - wrapperMargin.right -
        wrapperPadding.left - wrapperPadding.right - wrapperBorders.left -
        wrapperBorders.right;

    CGSize tableSize = [MarkdownTableView sizeForTableNode:node
                                               styleConfig:styleConfig
                                                  maxWidth:tableInnerWidth];
    CGSize framed = SizeForBlockStyle(tableStyle, tableSize);
    return framed.height;
  }

  // Text block (paragraph, heading, codeBlock, etc.)
  MarkdownElementStyle *blockStyle =
      BlockStyleForNodeType(type, node.headingLevel, styleConfig);

  UIEdgeInsets margin = [blockStyle resolvedMarginInsets];
  UIEdgeInsets padding = [blockStyle resolvedPaddingInsets];
  UIEdgeInsets borders = [blockStyle resolvedBorderWidths];
  CGFloat textWidth = innerWidth - margin.left - margin.right - padding.left -
                      padding.right - borders.left - borders.right;

  NSAttributedString *content =
      [RenderContext renderNodeToAttributedString:node
                                      styleConfig:styleConfig
                                       customTags:customTags
                                   inheritedAttrs:inheritedAttrs];
  CGSize textSize = MeasureAttributedString(content, textWidth);
  CGSize framed = SizeForBlockStyle(blockStyle, textSize);
  return framed.height;
}

@implementation MarkdownMeasurer

+ (CGSize)measureMarkdown:(NSString *)markdown
               stylesJSON:(NSString *)stylesJSON
               customTags:(NSArray<NSString *> *)customTags
           propImageSizes:(NSDictionary<NSString *, NSValue *> *)propImageSizes
                    width:(CGFloat)width {
  if (!markdown || markdown.length == 0 || width <= 0) {
    return CGSizeZero;
  }

  NSString *key =
      MakeCacheKey(markdown, stylesJSON, customTags, propImageSizes, width);
  NSValue *cached = [sMeasureCache() objectForKey:key];
  if (cached) {
    return [cached CGSizeValue];
  }

  StyleConfig *styleConfig = [StyleConfig fromJSON:stylesJSON ?: @""];

  UIEdgeInsets baseMargin = [styleConfig.base resolvedMarginInsets];
  UIEdgeInsets basePadding = [styleConfig.base resolvedPaddingInsets];
  UIEdgeInsets baseBorders = [styleConfig.base resolvedBorderWidths];
  CGFloat innerWidth = width - baseMargin.left - baseMargin.right -
                       basePadding.left - basePadding.right - baseBorders.left -
                       baseBorders.right;

  // Parse
  markdown::ParseOptions options;
  options.enableTables = true;
  options.enableStrikethrough = true;
  options.enableTaskLists = true;
  options.enableAutolinks = true;
  // Built-in custom tags — match MarkdownView.renderMarkdown.
  options.customTags.insert("UserMention");
  options.customTags.insert("ChannelMention");
  options.customTags.insert("CommandMention");
  options.customTags.insert("Spoiler");
  for (NSString *tag in customTags) {
    options.customTags.insert(std::string([tag UTF8String]));
  }
  std::string markdownStr([markdown UTF8String]);
  markdown::ASTNode ast = markdown::MarkdownParser::parse(markdownStr, options);
  ASTNodeWrapper *rootWrapper =
      [[ASTNodeWrapper alloc] initWithOpaqueNode:&ast];

  CGFloat totalHeight = 0;
  NSInteger segmentCount = 0;
  for (ASTNodeWrapper *child in rootWrapper.children) {
    CGFloat h = MeasureSegmentHeight(child, styleConfig, customTags,
                                     propImageSizes, innerWidth, nil);
    if (h > 0) {
      totalHeight += h;
      segmentCount++;
    }
  }

  if (segmentCount > 1) {
    totalHeight += styleConfig.base.gap * (segmentCount - 1);
  }

  totalHeight += baseMargin.top + baseMargin.bottom + basePadding.top +
                 basePadding.bottom + baseBorders.top + baseBorders.bottom;

  CGSize size = CGSizeMake(width, ceil(totalHeight));
  [sMeasureCache() setObject:[NSValue valueWithCGSize:size] forKey:key];
  return size;
}

+ (void)clearCache {
  [sMeasureCache() removeAllObjects];
}

@end
