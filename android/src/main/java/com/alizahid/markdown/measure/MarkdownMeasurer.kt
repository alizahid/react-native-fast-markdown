package com.alizahid.markdown.measure

import android.content.Context
import android.graphics.Typeface
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.util.Size
import com.alizahid.markdown.jni.MarkdownParserJni
import com.alizahid.markdown.parser.AstNode
import com.alizahid.markdown.parser.NodeType
import com.alizahid.markdown.renderer.RenderContext
import com.alizahid.markdown.style.StyleConfig
import com.alizahid.markdown.util.TypefaceResolver
import kotlin.math.ceil
import kotlin.math.max

/**
 * Thread-safe measurement entry point used by the Fabric ViewManager
 * `measure()` callback. Same render path as the runtime view layer so
 * heights agree.
 *
 * Phase 2 measures top-level Paragraph + Heading blocks. Phase 3 adds
 * blocks (list/blockquote/codeBlock/thematicBreak/table); Phase 4 wires
 * block-level images (with size cache + prop image data lookup).
 */
object MarkdownMeasurer {

  fun measure(
    context: Context,
    markdown: String,
    styles: String?,
    customTags: Set<String>,
    propImageSizesKey: String,
    availableWidthPx: Float,
  ): Size {
    val widthInt = max(0, availableWidthPx.toInt())
    val key = buildKey(markdown, styles, customTags, propImageSizesKey, widthInt)
    MeasurementCache.get(key)?.let { return it }

    val ast = MarkdownParserJni.parse(markdown, customTags) ?: return Size(widthInt, 0)
    val cfg = StyleConfig.fromJson(styles)

    val baseGap = cfg.base.gap.let { if (it.isNaN()) 0f else it }
    val basePadding = cfg.base.resolvedPaddingInsets()
    val baseMargin = cfg.base.resolvedMarginInsets()
    val innerWidth = (widthInt - basePadding.left - basePadding.right - baseMargin.left - baseMargin.right)
      .coerceAtLeast(0)

    var totalHeight = basePadding.top + basePadding.bottom + baseMargin.top + baseMargin.bottom
    var visibleCount = 0

    for (child in ast.children) {
      val h = measureSegment(child, cfg, customTags, innerWidth.toFloat()) ?: continue
      totalHeight += h
      visibleCount++
    }
    if (visibleCount > 1) totalHeight += (baseGap.toInt()) * (visibleCount - 1)

    val out = Size(widthInt, totalHeight)
    MeasurementCache.put(key, out)
    return out
  }

  /**
   * Measures one top-level segment to a pixel height. Returns null if
   * the node type isn't yet supported (treated as zero contribution).
   */
  private fun measureSegment(
    node: AstNode,
    cfg: StyleConfig,
    customTags: Set<String>,
    widthPx: Float,
  ): Int? {
    return when (node.type) {
      NodeType.Paragraph, NodeType.Heading -> measureText(node, cfg, customTags, widthPx)
      NodeType.ThematicBreak -> {
        val s = cfg.thematicBreak
        val h = if (!s.height.isNaN() && s.height > 0) s.height.toInt() else 1
        val m = s.resolvedMarginInsets()
        h + m.top + m.bottom
      }
      // Phase 3+ wire up List, Blockquote, CodeBlock, Table, etc.
      else -> 0
    }
  }

  private fun measureText(
    node: AstNode,
    cfg: StyleConfig,
    customTags: Set<String>,
    widthPx: Float,
  ): Int {
    val spanned = RenderContext.renderNodeToSpanned(node, cfg, customTags)
    val style = when (node.type) {
      NodeType.Heading -> cfg.styleForHeadingLevel(node.headingLevel)
      else -> cfg.paragraph
    }
    val padding = style.resolvedPaddingInsets()
    val margin = style.resolvedMarginInsets()
    val borders = style.resolvedBorderWidths()
    val horizontalChrome = padding.left + padding.right + margin.left + margin.right +
      borders.left + borders.right
    val textWidth = (widthPx.toInt() - horizontalChrome).coerceAtLeast(1)

    val paint = TextPaint().apply {
      isAntiAlias = true
      val baseTf = TypefaceResolver.resolve(cfg.base, Typeface.DEFAULT)
      typeface = baseTf
      textSize = pickFontSize(cfg, style)
    }
    val layout = StaticLayout.Builder.obtain(spanned, 0, spanned.length, paint, textWidth)
      .setAlignment(Layout.Alignment.ALIGN_NORMAL)
      .setIncludePad(false)
      .setLineSpacing(0f, 1f)
      .build()
    val textHeight = ceil(layout.height.toDouble()).toInt()
    return textHeight + padding.top + padding.bottom + margin.top + margin.bottom +
      borders.top + borders.bottom
  }

  private fun pickFontSize(cfg: StyleConfig, style: com.alizahid.markdown.style.ElementStyle): Float {
    if (!style.fontSize.isNaN() && style.fontSize > 0) return style.fontSize
    if (!cfg.base.fontSize.isNaN() && cfg.base.fontSize > 0) return cfg.base.fontSize
    return 16f
  }

  private fun buildKey(
    markdown: String, styles: String?, customTags: Set<String>,
    propImageSizesKey: String, width: Int,
  ): String =
    "$width|${customTags.sorted().joinToString(",")}|$propImageSizesKey|${styles ?: ""}|$markdown"
}
