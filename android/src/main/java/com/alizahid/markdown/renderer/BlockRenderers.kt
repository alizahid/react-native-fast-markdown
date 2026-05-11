package com.alizahid.markdown.renderer

import android.graphics.Typeface
import android.text.SpannableStringBuilder
import com.alizahid.markdown.parser.AstNode
import com.alizahid.markdown.renderer.RenderContext.Companion.ATTR_FONT_SIZE
import com.alizahid.markdown.renderer.RenderContext.Companion.ATTR_TYPEFACE
import com.alizahid.markdown.renderer.RenderContext.Companion.resolveAttrs

/**
 * Block renderers that produce attributed text (paragraph, heading).
 * True container blocks (list, blockquote, codeBlock, table) are wrapped
 * into MarkdownBlockView at the view layer — those renderers are in
 * Phase 3.
 */

object ParagraphRenderer : NodeRenderer {
  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    val style = ctx.styleConfig.paragraph
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
    ctx.popAttributes()
  }
}
