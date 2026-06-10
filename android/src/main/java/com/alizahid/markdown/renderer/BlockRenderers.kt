package com.alizahid.markdown.renderer

import android.text.SpannableStringBuilder
import com.alizahid.markdown.parser.AstNode
import com.alizahid.markdown.renderer.RenderContext.Companion.mergeStyleAttrs
import com.alizahid.markdown.style.ElementStyle
import com.alizahid.markdown.style.StyleConfig

/**
 * Block renderers that produce attributed text. Mirrors
 * ParagraphRenderer.m / HeadingRenderer.m / BlockquoteRenderer.m:
 * character styling cascades through the attribute stack (leaf-applied),
 * while paragraph-level properties (lineHeight, textAlign) are applied
 * over the block's own range here.
 */

/**
 * Applies paragraph-level spans over `[start, end)`, with the element
 * style winning over the base style. Paragraphs cascade lineHeight /
 * textAlign from base (iOS applyParagraphPropertiesFromStyle:base);
 * headings deliberately don't — base lineHeight tuned for body text
 * clips against large heading fonts (see iOS HeadingRenderer.m, which
 * only applies the heading's own style).
 */
internal fun applyBlockParagraphProps(
  style: ElementStyle,
  base: ElementStyle?,
  into: SpannableStringBuilder,
  start: Int,
  end: Int,
) {
  if (start >= end) return
  val lineHeight = when {
    !style.lineHeight.isNaN() && style.lineHeight > 0 -> style.lineHeight
    base != null && !base.lineHeight.isNaN() && base.lineHeight > 0 -> base.lineHeight
    else -> Float.NaN
  }
  val align = style.textAlign ?: base?.textAlign
  StyleAttributes.applyParagraphProperties(lineHeight, align, into, start, end)
}

object ParagraphRenderer : NodeRenderer {
  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    val style = ctx.styleConfig.paragraph
    ctx.pushAttributes(mergeStyleAttrs(style, ctx.currentAttributes()))
    val start = into.length
    ctx.renderChildren(node, into)
    val end = into.length
    applyBlockParagraphProps(style, ctx.styleConfig.base, into, start, end)
    ctx.popAttributes()
    // Paragraph spacing — mirrors iOS: append a separating newline when
    // the buffer has content, so stacked paragraphs (e.g. inside a
    // blockquote) split into lines. The static renderNodeToSpanned
    // helper trims trailing newlines for top-level use.
    if (into.isNotEmpty()) into.append('\n')
  }
}

object HeadingRenderer : NodeRenderer {
  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    val style = ctx.styleConfig.styleForHeadingLevel(node.headingLevel)
    ctx.pushAttributes(mergeStyleAttrs(style, ctx.currentAttributes()))
    val start = into.length
    ctx.renderChildren(node, into)
    val end = into.length
    // Headings apply only their own paragraph props — no base cascade.
    applyBlockParagraphProps(style, base = null, into, start, end)
    ctx.popAttributes()
    into.append('\n')
  }
}

object BlockquoteRenderer : NodeRenderer {
  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    val style = ctx.styleConfig.blockquote
    val wasInside = ctx.isInsideBlockquote
    ctx.isInsideBlockquote = true
    ctx.pushAttributes(mergeStyleAttrs(style, ctx.currentAttributes()))
    ctx.renderChildren(node, into)
    ctx.popAttributes()
    ctx.isInsideBlockquote = wasInside
  }
}

/**
 * Shared helper for view-layer cascades: the attributes children of a
 * container block (blockquote) inherit. Mirrors the childAttrs
 * composition in iOS addBlockquoteSegment.
 */
fun blockChildAttrs(
  style: ElementStyle,
  cfg: StyleConfig,
  inherited: Map<String, Any?>?,
): Map<String, Any?> =
  mergeStyleAttrs(style, inherited ?: RenderContext.baseAttributesFromStyleConfig(cfg))
