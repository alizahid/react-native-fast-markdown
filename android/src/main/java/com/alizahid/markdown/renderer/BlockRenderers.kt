package com.alizahid.markdown.renderer

import android.graphics.Typeface
import android.text.SpannableStringBuilder
import com.alizahid.markdown.parser.AstNode
import com.alizahid.markdown.renderer.RenderContext.Companion.ATTR_FONT_SIZE
import com.alizahid.markdown.renderer.RenderContext.Companion.ATTR_TYPEFACE
import com.alizahid.markdown.renderer.RenderContext.Companion.resolveAttrs

/**
 * Block renderers that produce attributed text (paragraph, heading).
 * True container blocks (list, blockquote, table) are wrapped into a
 * MarkdownBlockView at the view layer — but the renderers exist so
 * nested cases (e.g. paragraph inside blockquote) render to a single
 * SpannableStringBuilder.
 */

/**
 * Applies the BASE style's paragraph-level properties (lineHeight,
 * textAlign) before any element-specific style. Mirrors iOS
 * `+ [StyleAttributes applyParagraphPropertiesFromStyle:base toAttrs:]`
 * being called before `applyStyle:paragraph` in ParagraphRenderer.m —
 * without this, top-level paragraphs lose any line height set on the
 * base style.
 */
private fun applyBaseParagraphProps(
  ctx: RenderContext,
  into: SpannableStringBuilder,
  start: Int,
  end: Int,
) {
  if (start >= end) return
  val base = ctx.styleConfig.base
  // Only line-height + text-align matter here; font/color cascades via
  // the attribute stack.
  if ((!base.lineHeight.isNaN() && base.lineHeight > 0) || base.textAlign != null) {
    StyleAttributes.applyParagraphProperties(base, into, start, end)
  }
}

object ParagraphRenderer : NodeRenderer {
  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    val style = ctx.styleConfig.paragraph
    val inherited = ctx.currentAttributes()
    val resolved = resolveAttrs(style, inherited)
    ctx.pushAttributes(resolved)
    val start = into.length
    ctx.renderChildren(node, into)
    val end = into.length
    applyBaseParagraphProps(ctx, into, start, end)
    StyleAttributes.apply(
      style, into, start, end,
      resolved[ATTR_TYPEFACE] as? Typeface,
      resolved[ATTR_FONT_SIZE] as? Float,
    )
    // Append a trailing newline so multiple paragraphs (e.g. inside a
    // blockquote) separate correctly when rendered into a single buffer.
    // The static `renderNodeToSpanned` helper trims one trailing newline
    // for top-level use, so this is harmless there.
    if (end > start) into.append('\n')
    ctx.popAttributes()
  }
}

object HeadingRenderer : NodeRenderer {
  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    val style = ctx.styleConfig.styleForHeadingLevel(node.headingLevel)
    val inherited = ctx.currentAttributes()
    val resolved = resolveAttrs(style, inherited)
    ctx.pushAttributes(resolved)
    val start = into.length
    ctx.renderChildren(node, into)
    val end = into.length
    StyleAttributes.apply(
      style, into, start, end,
      resolved[ATTR_TYPEFACE] as? Typeface,
      resolved[ATTR_FONT_SIZE] as? Float,
    )
    if (end > start) into.append('\n')
    ctx.popAttributes()
  }
}
