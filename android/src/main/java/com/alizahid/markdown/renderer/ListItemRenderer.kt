package com.alizahid.markdown.renderer

import android.graphics.Typeface
import android.text.SpannableStringBuilder
import com.alizahid.markdown.parser.AstNode
import com.alizahid.markdown.renderer.RenderContext.Companion.ATTR_FONT_SIZE
import com.alizahid.markdown.renderer.RenderContext.Companion.ATTR_TYPEFACE
import com.alizahid.markdown.renderer.RenderContext.Companion.resolveAttrs

/**
 * Mirrors ios/renderer/ListItemRenderer.m. Emits an optional leading
 * newline, an indent + bullet/number prefix styled with listBullet, then
 * the item's children, then a trailing newline.
 *
 * Indent depth, ordered/unordered, marker number, and max-marker digits
 * for column alignment all come from RenderContext.
 */
object ListItemRenderer : NodeRenderer {

  private val bulletGlyphs = arrayOf("• ", "◦ ", "▪ ")
  private const val FIGURE_SPACE = ' '

  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    val itemStyle = ctx.styleConfig.listItem
    val inherited = ctx.currentAttributes()
    val resolved = resolveAttrs(itemStyle, inherited)

    // Force a separating newline if the buffer doesn't already end on
    // one — md4c omits MD_BLOCK_P inside tight lists, so without this
    // the next item's bullet lands on the same line.
    val len = into.length
    if (len > 0 && into[len - 1] != '\n') into.append('\n')

    val indentBuilder = StringBuilder()
    repeat((ctx.listDepth - 1).coerceAtLeast(0)) { indentBuilder.append("    ") }

    val bullet: String = if (ctx.currentListIsOrdered) {
      val number = ctx.orderedListIndex
      val digits = digitsOf(number)
      val padCount = (ctx.currentListMaxMarkerDigits - digits).coerceAtLeast(0)
      val padding = buildString { repeat(padCount) { append(FIGURE_SPACE) } }
      val out = "$padding$number. "
      ctx.orderedListIndex = number + 1
      out
    } else {
      val idx = ((ctx.listDepth - 1).coerceAtLeast(0)) % bulletGlyphs.size
      bulletGlyphs[idx]
    }
    val prefix = indentBuilder.toString() + bullet

    val prefixStart = into.length
    into.append(prefix)
    val prefixEnd = into.length

    // Apply listItem then listBullet styling to the prefix range. The
    // prefix's typeface inherits from itemStyle so digit widths line up.
    val bulletAttrs = resolveAttrs(ctx.styleConfig.listBullet, resolved)
    StyleAttributes.apply(
      ctx.styleConfig.listItem, into, prefixStart, prefixEnd,
      resolved[ATTR_TYPEFACE] as? Typeface,
      resolved[ATTR_FONT_SIZE] as? Float,
    )
    StyleAttributes.apply(
      ctx.styleConfig.listBullet, into, prefixStart, prefixEnd,
      bulletAttrs[ATTR_TYPEFACE] as? Typeface,
      bulletAttrs[ATTR_FONT_SIZE] as? Float,
    )

    ctx.pushAttributes(resolved)
    val bodyStart = into.length
    ctx.renderChildren(node, into)
    val bodyEnd = into.length

    StyleAttributes.apply(
      ctx.styleConfig.listItem, into, bodyStart, bodyEnd,
      resolved[ATTR_TYPEFACE] as? Typeface,
      resolved[ATTR_FONT_SIZE] as? Float,
    )

    ctx.popAttributes()

    if (into.isNotEmpty() && into[into.length - 1] != '\n') into.append('\n')
  }

  private fun digitsOf(n: Int): Int {
    var v = maxOf(1, n)
    var d = 1
    while (v >= 10) { d++; v /= 10 }
    return d
  }
}
