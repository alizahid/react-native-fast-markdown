package com.fastmarkdown.render

import android.graphics.Color
import android.graphics.Typeface
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.TextPaint
import android.text.style.StyleSpan
import com.fastmarkdown.parser.MdNode
import com.fastmarkdown.parser.MdNodeType
import com.fastmarkdown.style.StyleConfig

/**
 * AST -> list of renderable blocks. M1 handles paragraph/heading text with
 * basic bold/italic spans; the full element set arrives with M2/M3.
 */
object SpannableRenderer {
  fun render(root: MdNode, styles: StyleConfig, density: Float, fontScale: Float): List<Block> {
    val blocks = ArrayList<Block>()
    for (child in root.children) {
      renderBlock(child, styles, density, fontScale, blocks)
    }
    return blocks
  }

  private fun renderBlock(
    node: MdNode,
    styles: StyleConfig,
    density: Float,
    fontScale: Float,
    out: MutableList<Block>,
  ) {
    when (node.type) {
      MdNodeType.PARAGRAPH -> {
        out.add(Block.Text(renderInlines(node), textPaint(styles.fontSize(0), density, fontScale, bold = false)))
      }
      MdNodeType.HEADING -> {
        out.add(
          Block.Text(
            renderInlines(node),
            textPaint(styles.fontSize(node.level), density, fontScale, bold = true),
          )
        )
      }
      else -> {
        // Other block types land in M3+; render their inline text meanwhile
        // so content is never silently dropped.
        if (node.children.isNotEmpty()) {
          for (child in node.children) {
            renderBlock(child, styles, density, fontScale, out)
          }
        } else if (node.text.isNotEmpty()) {
          out.add(Block.Text(node.text, textPaint(styles.fontSize(0), density, fontScale, bold = false)))
        }
      }
    }
  }

  private fun renderInlines(parent: MdNode): CharSequence {
    val builder = SpannableStringBuilder()
    appendInlines(builder, parent)
    return builder
  }

  private fun appendInlines(builder: SpannableStringBuilder, parent: MdNode) {
    for (node in parent.children) {
      when (node.type) {
        MdNodeType.TEXT -> builder.append(node.text)
        MdNodeType.SOFT_BREAK -> builder.append(' ')
        MdNodeType.HARD_BREAK -> builder.append('\n')
        MdNodeType.BOLD -> appendStyled(builder, node, StyleSpan(Typeface.BOLD))
        MdNodeType.ITALIC -> appendStyled(builder, node, StyleSpan(Typeface.ITALIC))
        MdNodeType.INLINE_CODE -> builder.append(node.text)
        MdNodeType.IMAGE -> builder.append(node.text)
        else -> appendInlines(builder, node)
      }
    }
  }

  private fun appendStyled(builder: SpannableStringBuilder, node: MdNode, span: Any) {
    val start = builder.length
    appendInlines(builder, node)
    builder.setSpan(span, start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
  }

  private fun textPaint(sizeDp: Float, density: Float, fontScale: Float, bold: Boolean): TextPaint {
    return TextPaint().apply {
      isAntiAlias = true
      color = Color.BLACK
      textSize = sizeDp * density * fontScale
      typeface = if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
    }
  }
}
