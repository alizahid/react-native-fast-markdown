package com.alizahid.markdown.renderer

import android.text.SpannableStringBuilder
import com.alizahid.markdown.parser.AstNode

/**
 * Mirrors `NodeRenderer` protocol in ios/renderer/NodeRenderer.h.
 * Each renderer appends to the output SpannableStringBuilder, optionally
 * pushing/popping attributes on the context's attribute stack.
 */
interface NodeRenderer {
  fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext)
}
