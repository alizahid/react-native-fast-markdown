package com.alizahid.markdown.renderer

import android.text.SpannableStringBuilder
import com.alizahid.markdown.parser.AstNode
import com.alizahid.markdown.renderer.RenderContext.Companion.resolveAttrs

/**
 * Mirrors ios/renderer/BlockquoteRenderer.m: pushes the blockquote text
 * style onto the attribute stack, marks `isInsideBlockquote = true`,
 * renders children, then pops. The visible quote bar / background comes
 * from the wrapping MarkdownBlockView built by MarkdownView at the view
 * layer.
 */
object BlockquoteRenderer : NodeRenderer {
  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    val style = ctx.styleConfig.blockquote
    val resolved = resolveAttrs(style, ctx.currentAttributes())
    val wasInside = ctx.isInsideBlockquote
    ctx.isInsideBlockquote = true
    ctx.pushAttributes(resolved)
    ctx.renderChildren(node, into)
    ctx.popAttributes()
    ctx.isInsideBlockquote = wasInside
  }
}
