package com.alizahid.markdown.measure

import android.content.Context
import android.graphics.Typeface
import android.text.Layout
import android.text.Spanned
import android.text.StaticLayout
import android.text.TextPaint
import android.util.Size
import com.alizahid.markdown.jni.MarkdownParserJni
import com.alizahid.markdown.parser.AstNode
import com.alizahid.markdown.parser.ListType
import com.alizahid.markdown.parser.NodeType
import com.alizahid.markdown.renderer.RenderContext
import com.alizahid.markdown.style.ElementStyle
import com.alizahid.markdown.style.StyleConfig
import com.alizahid.markdown.util.TypefaceResolver
import com.alizahid.markdown.view.MarkdownTableLayout
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min

/**
 * Thread-safe measurement entry point. Mirrors ios/MarkdownMeasurer.mm
 * branch-for-branch so the height Yoga reserves matches the height the
 * runtime view layer renders.
 *
 * The output is meant to be consumed by a future Yoga measure-function
 * wiring; until that lands the runtime view's own `onMeasure` is what
 * sizes the component. Keeping this in sync now prevents drift later.
 */
object MarkdownMeasurer {

  private const val DEFAULT_IMAGE_HEIGHT_PX = 200

  fun measure(
    context: Context,
    markdown: String,
    styles: String?,
    customTags: Set<String>,
    propImageSizes: Map<String, Size>,
    availableWidthPx: Float,
  ): Size {
    if (markdown.isEmpty() || availableWidthPx <= 0f) return Size(0, 0)
    val widthInt = availableWidthPx.toInt().coerceAtLeast(0)
    val key = buildKey(markdown, styles, customTags, propImageSizes, widthInt)
    MeasurementCache.get(key)?.let { return it }

    val cfg = StyleConfig.fromJson(styles)
    val baseMargin = cfg.base.resolvedMarginInsets()
    val basePadding = cfg.base.resolvedPaddingInsets()
    val baseBorders = cfg.base.resolvedBorderWidths()
    val innerWidth = widthInt - baseMargin.left - baseMargin.right -
      basePadding.left - basePadding.right -
      baseBorders.left - baseBorders.right

    val ast = MarkdownParserJni.parse(markdown, customTags) ?: return Size(widthInt, 0)

    var totalHeight = 0
    var visibleSegments = 0
    for (child in ast.children) {
      val h = measureSegmentHeight(child, cfg, customTags, propImageSizes, innerWidth, null)
      if (h > 0) {
        totalHeight += h
        visibleSegments++
      }
    }
    val gap = if (!cfg.base.gap.isNaN()) cfg.base.gap.toInt() else 0
    if (visibleSegments > 1) totalHeight += gap * (visibleSegments - 1)

    totalHeight += baseMargin.top + baseMargin.bottom +
      basePadding.top + basePadding.bottom +
      baseBorders.top + baseBorders.bottom

    val out = Size(widthInt, totalHeight)
    MeasurementCache.put(key, out)
    return out
  }

  /**
   * Height of a single top-level block for an available inner width.
   * `inheritedAttrs` carries text styling cascaded down from parents
   * (e.g. a blockquote's color/fontStyle applied to its children).
   */
  private fun measureSegmentHeight(
    node: AstNode,
    cfg: StyleConfig,
    customTags: Set<String>,
    propImageSizes: Map<String, Size>,
    innerWidth: Int,
    inheritedAttrs: Map<String, Any?>?,
  ): Int {
    // `![](url)` on its own line ⇒ block image segment.
    RenderContext.imageOnlyParagraphChild(node)?.let { imageChild ->
      return measureImageBlock(imageChild, cfg, propImageSizes, innerWidth)
    }

    return when (node.type) {
      NodeType.ThematicBreak -> sizeForBlockStyle(cfg.thematicBreak, 0, 0).height
      NodeType.Blockquote -> measureBlockquote(node, cfg, customTags, propImageSizes, innerWidth, inheritedAttrs)
      NodeType.List -> measureList(node, cfg, customTags, innerWidth, inheritedAttrs)
      NodeType.Table -> measureTable(node, cfg, customTags, innerWidth)
      else -> measureTextBlock(node, cfg, customTags, innerWidth, inheritedAttrs)
    }
  }

  private fun measureImageBlock(
    imageNode: AstNode,
    cfg: StyleConfig,
    propImageSizes: Map<String, Size>,
    innerWidth: Int,
  ): Int {
    val style = cfg.image
    val padding = style.resolvedPaddingInsets()
    val borders = style.resolvedBorderWidths()
    val margin = style.resolvedMarginInsets()
    val contentWidth = innerWidth - padding.left - padding.right -
      borders.left - borders.right - margin.left - margin.right

    val url = imageNode.imageSrc
    val natural = propImageSizes[url]
      ?: com.alizahid.markdown.view.MarkdownImageSizeCache.get(url)

    val contentSize = if (natural != null && natural.width > 0 && natural.height > 0 && contentWidth > 0) {
      // Mirror MarkdownImageView.blockSizeForNaturalSize. cover with both
      // maxW/maxH ⇒ exact (maxW, maxH); otherwise natural scaled to fit
      // max constraints; then clamp to available width.
      val maxW = pickMax(style.maxWidth)
      val maxH = pickMax(style.maxHeight)
      val objectFit = style.objectFit
      val cover = objectFit != "contain"
      var w: Float; var h: Float
      if (cover && maxW > 0 && maxH > 0) {
        w = maxW.toFloat(); h = maxH.toFloat()
      } else {
        w = natural.width.toFloat(); h = natural.height.toFloat()
        var scale = 1f
        if (maxW > 0 && w > maxW) scale = min(scale, maxW / w)
        if (maxH > 0 && h > maxH) scale = min(scale, maxH / h)
        w *= scale; h *= scale
      }
      if (contentWidth > 0 && w > contentWidth) {
        val s = contentWidth / w
        w *= s; h *= s
      }
      Size(ceil(w).toInt(), ceil(h).toInt())
    } else {
      val h = if (!style.height.isNaN() && style.height > 0) style.height.toInt() else DEFAULT_IMAGE_HEIGHT_PX
      Size(contentWidth.coerceAtLeast(0), h)
    }

    return sizeForBlockStyle(style, contentSize.width, contentSize.height).height
  }

  private fun pickMax(value: Float): Int = if (!value.isNaN() && value > 0) value.toInt() else 0

  private fun measureBlockquote(
    node: AstNode, cfg: StyleConfig, customTags: Set<String>,
    propImageSizes: Map<String, Size>, innerWidth: Int,
    inheritedAttrs: Map<String, Any?>?,
  ): Int {
    val style = cfg.blockquote
    val margin = style.resolvedMarginInsets()
    val padding = style.resolvedPaddingInsets()
    val borders = style.resolvedBorderWidths()
    val childInner = innerWidth - margin.left - margin.right -
      padding.left - padding.right - borders.left - borders.right

    val parentAttrs = inheritedAttrs ?: RenderContext.baseAttributesFromStyleConfig(cfg)
    val childAttrs = RenderContext.resolveAttrs(style, parentAttrs)

    var total = 0; var visible = 0
    for (child in node.children) {
      val h = measureSegmentHeight(child, cfg, customTags, propImageSizes, childInner, childAttrs)
      if (h > 0) { total += h; visible++ }
    }
    if (visible > 1) {
      val gap = if (!style.gap.isNaN()) style.gap.toInt() else 0
      total += gap * (visible - 1)
    }
    return sizeForBlockStyle(style, 0, total).height
  }

  private fun measureList(
    node: AstNode, cfg: StyleConfig, customTags: Set<String>,
    innerWidth: Int, inheritedAttrs: Map<String, Any?>?,
  ): Int {
    val listStyle = cfg.list
    val itemStyle = cfg.listItem
    val listMargin = listStyle.resolvedMarginInsets()
    val listPadding = listStyle.resolvedPaddingInsets()
    val listBorders = listStyle.resolvedBorderWidths()
    val itemWidth = innerWidth - listMargin.left - listMargin.right -
      listPadding.left - listPadding.right - listBorders.left - listBorders.right

    val itemMargin = itemStyle.resolvedMarginInsets()
    val itemPadding = itemStyle.resolvedPaddingInsets()
    val itemBorders = itemStyle.resolvedBorderWidths()
    val itemContentWidth = itemWidth - itemMargin.left - itemMargin.right -
      itemPadding.left - itemPadding.right - itemBorders.left - itemBorders.right

    val isOrdered = node.listType == ListType.Ordered
    val itemCount = node.children.count { it.type == NodeType.ListItem }
    val startNumber = if (isOrdered && node.listStart > 0) node.listStart else 1
    val lastNumber = max(1, startNumber + itemCount - 1)
    var maxDigits = 1; var v = lastNumber
    while (v >= 10) { maxDigits++; v /= 10 }

    val paint = paintFor(cfg, itemStyle)
    var orderedIndex = startNumber
    var total = 0; var visible = 0
    for (child in node.children) {
      if (child.type != NodeType.ListItem) continue
      val content = RenderContext.renderListItemContent(
        child, isOrdered, orderedIndex, maxDigits, cfg, customTags, inheritedAttrs,
      )
      if (isOrdered) orderedIndex++
      val textHeight = layoutHeight(content, paint, itemContentWidth.coerceAtLeast(1))
      total += sizeForBlockStyle(itemStyle, itemContentWidth, textHeight).height
      visible++
    }
    if (visible > 1) {
      val gap = if (!listStyle.gap.isNaN()) listStyle.gap.toInt() else 0
      total += gap * (visible - 1)
    }
    return sizeForBlockStyle(listStyle, 0, total).height
  }

  private fun measureTable(
    node: AstNode, cfg: StyleConfig, customTags: Set<String>, innerWidth: Int,
  ): Int {
    val style = cfg.table
    val margin = style.resolvedMarginInsets()
    val padding = style.resolvedPaddingInsets()
    val borders = style.resolvedBorderWidths()
    val tableInner = innerWidth - margin.left - margin.right -
      padding.left - padding.right - borders.left - borders.right

    val layout = MarkdownTableLayout.compute(node, cfg, customTags, tableInner.coerceAtLeast(0))
    return sizeForBlockStyle(style, layout.totalWidth, layout.totalHeight).height
  }

  private fun measureTextBlock(
    node: AstNode, cfg: StyleConfig, customTags: Set<String>,
    innerWidth: Int, inheritedAttrs: Map<String, Any?>?,
  ): Int {
    val style = blockStyleForNode(node, cfg) ?: cfg.paragraph
    val margin = style.resolvedMarginInsets()
    val padding = style.resolvedPaddingInsets()
    val borders = style.resolvedBorderWidths()
    val textWidth = innerWidth - margin.left - margin.right -
      padding.left - padding.right - borders.left - borders.right

    val content = RenderContext.renderNodeToSpanned(node, cfg, customTags, inheritedAttrs)
    val paint = paintFor(cfg, style)
    val textHeight = layoutHeight(content, paint, textWidth.coerceAtLeast(1))
    return sizeForBlockStyle(style, textWidth, textHeight).height
  }

  private fun blockStyleForNode(node: AstNode, cfg: StyleConfig): ElementStyle? = when (node.type) {
    NodeType.Paragraph -> cfg.paragraph
    NodeType.Heading -> cfg.styleForHeadingLevel(node.headingLevel)
    NodeType.CodeBlock -> cfg.codeBlock
    NodeType.Blockquote -> cfg.blockquote
    else -> null
  }

  private fun layoutHeight(text: CharSequence, paint: TextPaint, width: Int): Int {
    if (text.isEmpty() || width <= 0) return 0
    val layout = StaticLayout.Builder
      .obtain(text, 0, text.length, paint, width)
      .setAlignment(Layout.Alignment.ALIGN_NORMAL)
      .setIncludePad(false)
      .setLineSpacing(0f, 1f)
      .build()
    return ceil(layout.height.toDouble()).toInt()
  }

  private fun paintFor(cfg: StyleConfig, style: ElementStyle): TextPaint =
    TextPaint().apply {
      isAntiAlias = true
      val baseTf = TypefaceResolver.resolve(cfg.base, Typeface.DEFAULT)
      typeface = TypefaceResolver.resolve(style, baseTf)
      textSize = pickFontSize(cfg, style)
    }

  private fun pickFontSize(cfg: StyleConfig, style: ElementStyle): Float {
    if (!style.fontSize.isNaN() && style.fontSize > 0) return style.fontSize
    if (!cfg.base.fontSize.isNaN() && cfg.base.fontSize > 0) return cfg.base.fontSize
    return 16f
  }

  /**
   * Mirrors iOS SizeForBlockStyle: contentSize + padding + borders +
   * margin (margin is added to the OUTER frame). Explicit style.width /
   * style.height overrides the calculated content-box dimensions.
   */
  private fun sizeForBlockStyle(style: ElementStyle, contentW: Int, contentH: Int): Size {
    val margin = style.resolvedMarginInsets()
    val padding = style.resolvedPaddingInsets()
    val borders = style.resolvedBorderWidths()

    val marginW = margin.left + margin.right
    val marginH = margin.top + margin.bottom
    val extraW = padding.left + padding.right + borders.left + borders.right
    val extraH = padding.top + padding.bottom + borders.top + borders.bottom

    val borderBoxW = if (!style.width.isNaN() && style.width > 0) style.width.toInt() else contentW + extraW
    val borderBoxH = if (!style.height.isNaN() && style.height > 0) style.height.toInt() else contentH + extraH

    return Size(borderBoxW + marginW, borderBoxH + marginH)
  }

  private fun buildKey(
    markdown: String, styles: String?, customTags: Set<String>,
    propImageSizes: Map<String, Size>, width: Int,
  ): String {
    val tagsKey = customTags.sorted().joinToString(",")
    val imgKey = propImageSizes.toSortedMap().entries.joinToString("|") {
      "${it.key}:${it.value.width}x${it.value.height}"
    }
    return "$width|$tagsKey|$imgKey|${styles ?: ""}|$markdown"
  }
}
