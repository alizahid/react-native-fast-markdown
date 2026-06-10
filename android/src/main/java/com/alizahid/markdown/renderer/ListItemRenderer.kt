package com.alizahid.markdown.renderer

import android.text.SpannableStringBuilder
import com.alizahid.markdown.parser.AstNode
import com.alizahid.markdown.renderer.RenderContext.Companion.applyAttributes
import com.alizahid.markdown.renderer.RenderContext.Companion.mergeStyleAttrs

/**
 * Mirrors ios/renderer/ListItemRenderer.m. Emits an optional separating
 * newline, an indent + bullet/number prefix styled with listBullet over
 * the listItem cascade, then the item's children with listItem attrs
 * pushed, then a trailing newline.
 */
object ListItemRenderer : NodeRenderer {

  private val bulletGlyphs = arrayOf("• ", "◦ ", "▪ ")

  /** Digit-width space (U+2007) — pads ordered markers so periods align. */
  private const val FIGURE_SPACE = '\u2007'

  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    val itemStyle = ctx.styleConfig.listItem
    val itemAttrs = mergeStyleAttrs(itemStyle, ctx.currentAttributes())
    val bulletAttrs = mergeStyleAttrs(ctx.styleConfig.listBullet, itemAttrs)

    // md4c omits MD_BLOCK_P for items in tight lists, so an item's text
    // can end without a newline — force a separator so the next item's
    // bullet doesn't land on the same line.
    if (into.isNotEmpty() && into[into.length - 1] != '\n') into.append('\n')

    val indent = "    ".repeat((ctx.listDepth - 1).coerceAtLeast(0))

    val bullet: String = if (ctx.currentListIsOrdered) {
      val number = ctx.orderedListIndex
      val digits = digitsOf(number)
      val padCount = (ctx.currentListMaxMarkerDigits - digits).coerceAtLeast(0)
      ctx.orderedListIndex = number + 1
      buildString {
        repeat(padCount) { append(FIGURE_SPACE) }
        append(number)
        append(". ")
      }
    } else {
      bulletGlyphs[((ctx.listDepth - 1).coerceAtLeast(0)) % bulletGlyphs.size]
    }

    val itemStart = into.length
    into.append(indent)
    into.append(bullet)
    applyAttributes(bulletAttrs, into, itemStart, into.length)

    ctx.pushAttributes(itemAttrs)
    ctx.renderChildren(node, into)
    ctx.popAttributes()

    // lineHeight / textAlign for the item, cascading base like iOS
    // (applyParagraphPropertiesFromStyle:base + applyStyle:listItem).
    applyBlockParagraphProps(itemStyle, ctx.styleConfig.base, into, itemStart, into.length)

    if (into.isNotEmpty() && into[into.length - 1] != '\n') into.append('\n')
  }

  private fun digitsOf(n: Int): Int {
    var v = maxOf(1, n)
    var d = 1
    while (v >= 10) { d++; v /= 10 }
    return d
  }
}
