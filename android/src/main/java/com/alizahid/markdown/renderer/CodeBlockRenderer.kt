package com.alizahid.markdown.renderer

import android.text.SpannableStringBuilder
import com.alizahid.markdown.parser.AstNode
import com.alizahid.markdown.renderer.RenderContext.Companion.applyAttributes
import com.alizahid.markdown.renderer.RenderContext.Companion.mergeStyleAttrs

/**
 * Fenced code block. The wrapping MarkdownBlockView draws the tinted
 * box / border / radius; this renderer fills the attributed string with
 * the monospaced code text. Mirrors ios/renderer/CodeBlockRenderer.m.
 */
object CodeBlockRenderer : NodeRenderer {
  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    val style = ctx.styleConfig.codeBlock
    val wasInside = ctx.isInsideCodeBlock
    ctx.isInsideCodeBlock = true
    ctx.pushAttributes(mergeStyleAttrs(style, ctx.currentAttributes(), defaultMonospace = true))

    val start = into.length
    if (node.content.isNotEmpty()) {
      // md4c delivers fenced-code content on the node, not as children.
      into.append(node.content.trimEnd('\n'))
      applyAttributes(ctx.currentAttributes(), into, start, into.length)
    } else {
      ctx.renderChildren(node, into)
    }
    applyBlockParagraphProps(style, base = null, into, start, into.length)

    ctx.popAttributes()
    ctx.isInsideCodeBlock = wasInside

    // Ensure the block ends with a newline so subsequent blocks separate
    // cleanly in a shared buffer — mirrors iOS CodeBlockRenderer.m.
    if (into.isNotEmpty() && into[into.length - 1] != '\n') into.append('\n')
  }
}
