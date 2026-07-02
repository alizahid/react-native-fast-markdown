package com.fastmarkdown.render

import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.TextPaint
import com.fastmarkdown.parser.MdNode
import com.fastmarkdown.parser.MdNodeType
import com.fastmarkdown.render.spans.RunSpan
import com.fastmarkdown.style.StyleConfig
import com.fastmarkdown.style.TextStyleSpec

/**
 * AST -> renderable blocks. Inline runs carry one RunSpan each with the
 * fully-resolved attributes (mirrors the iOS attribute-stack renderer).
 */
object SpannableRenderer {
  private const val DEFAULT_LINK_COLOR = 0xFF007AFF.toInt()
  private const val DEFAULT_CODE_BACKGROUND = 0x14000000

  /** Fully-resolved text attributes at one point of the inline walk. */
  private data class ResolvedAttrs(
    val fontSizePx: Float,
    val weight: Int = 400,
    val italic: Boolean = false,
    val family: String? = null,
    val color: Int = Color.BLACK,
    val variants: List<String>? = null,
    val underline: Boolean = false,
    val strikethrough: Boolean = false,
    val baselineShiftPx: Int = 0,
    val backgroundColor: Int? = null,
  )

  private class Context(
    val styles: StyleConfig,
    val density: Float,
    val fontScale: Float,
  ) {
    fun apply(attrs: ResolvedAttrs, spec: TextStyleSpec?): ResolvedAttrs {
      if (spec == null) {
        return attrs
      }
      var next = attrs
      spec.fontSize?.let { next = next.copy(fontSizePx = it * density * fontScale) }
      spec.fontWeight?.let { next = next.copy(weight = it) }
      spec.fontFamily?.let { next = next.copy(family = it) }
      spec.color?.let { next = next.copy(color = it) }
      spec.fontVariant?.let { next = next.copy(variants = it) }
      spec.textDecorationLine?.let {
        next = next.copy(
          underline = it.contains("underline"),
          strikethrough = it.contains("line-through"),
        )
      }
      spec.backgroundColor?.let { next = next.copy(backgroundColor = it) }
      return next
    }

    fun apply(attrs: ResolvedAttrs, key: String): ResolvedAttrs =
      apply(attrs, styles.textStyleFor(key))
  }

  fun render(root: MdNode, styles: StyleConfig, density: Float, fontScale: Float): List<Block> {
    val context = Context(styles, density, fontScale)
    val blocks = ArrayList<Block>()
    for (child in root.children) {
      renderBlock(child, context, blocks)
    }
    return blocks
  }

  private fun renderBlock(node: MdNode, context: Context, out: MutableList<Block>) {
    when (node.type) {
      MdNodeType.PARAGRAPH, MdNodeType.HEADING -> {
        out.add(Block.Text(renderInlineBlock(node, context), basePaint(context)))
      }
      else -> {
        // Non-inline blocks land in M3+; render nested content meanwhile.
        if (node.children.isNotEmpty()) {
          for (child in node.children) {
            renderBlock(child, context, out)
          }
        } else if (node.text.isNotEmpty()) {
          val text = SpannableStringBuilder()
          val attrs = baseAttrs(node = null, context = context)
          appendRun(text, node.text, attrs, context)
          out.add(Block.Text(text, basePaint(context)))
        }
      }
    }
  }

  private fun basePaint(context: Context): TextPaint = TextPaint().apply {
    isAntiAlias = true
    textSize = context.styles.fontSize(0) * context.density * context.fontScale
  }

  private fun baseAttrs(node: MdNode?, context: Context): ResolvedAttrs {
    val styles = context.styles
    val scale = context.density * context.fontScale
    var attrs: ResolvedAttrs
    if (node != null && node.type == MdNodeType.HEADING) {
      attrs = ResolvedAttrs(fontSizePx = styles.fontSize(node.level) * scale, weight = 700)
      attrs = context.apply(attrs, "h${node.level}")
    } else {
      attrs = ResolvedAttrs(fontSizePx = styles.fontSize(0) * scale)
      attrs = context.apply(attrs, "paragraph")
    }
    return attrs
  }

  private fun renderInlineBlock(node: MdNode, context: Context): CharSequence {
    val builder = SpannableStringBuilder()
    walk(builder, node, baseAttrs(node, context), context)
    return builder
  }

  private fun walk(
    builder: SpannableStringBuilder,
    parent: MdNode,
    attrs: ResolvedAttrs,
    context: Context,
  ) {
    for (node in parent.children) {
      when (node.type) {
        MdNodeType.TEXT -> appendRun(builder, node.text, attrs, context)
        MdNodeType.SOFT_BREAK -> appendRun(builder, " ", attrs, context)
        MdNodeType.HARD_BREAK -> appendRun(builder, "\n", attrs, context)
        MdNodeType.BOLD ->
          walk(builder, node, context.apply(attrs.copy(weight = 700), "bold"), context)
        MdNodeType.ITALIC ->
          walk(builder, node, context.apply(attrs.copy(italic = true), "italic"), context)
        MdNodeType.STRIKETHROUGH ->
          walk(
            builder,
            node,
            context.apply(attrs.copy(strikethrough = true), "strikethrough"),
            context,
          )
        MdNodeType.LINK -> {
          var next = attrs.copy(color = DEFAULT_LINK_COLOR)
          val variant = context.styles.mentionVariants.firstOrNull {
            it.pattern.matcher(node.url).find()
          }
          next = if (variant != null) {
            context.apply(context.apply(next, "mention"), variant.style)
          } else {
            context.apply(next, "link")
          }
          walk(builder, node, next, context)
        }
        MdNodeType.INLINE_CODE -> {
          var next = attrs.copy(family = "monospace", backgroundColor = DEFAULT_CODE_BACKGROUND)
          next = context.apply(next, "inlineCode")
          appendRun(builder, node.text, next, context)
        }
        MdNodeType.SUPERSCRIPT -> {
          var next = attrs.copy(
            fontSizePx = attrs.fontSizePx * 0.7f,
            baselineShiftPx = (-attrs.fontSizePx * 0.35f).toInt(),
          )
          next = context.apply(next, "superscript")
          walk(builder, node, next, context)
        }
        MdNodeType.SUBSCRIPT -> {
          var next = attrs.copy(
            fontSizePx = attrs.fontSizePx * 0.7f,
            baselineShiftPx = (attrs.fontSizePx * 0.18f).toInt(),
          )
          next = context.apply(next, "subscript")
          walk(builder, node, next, context)
        }
        MdNodeType.SPOILER ->
          // Overlay + concealment land in M6; content renders styled now.
          walk(builder, node, attrs, context)
        MdNodeType.IMAGE -> appendRun(builder, node.text, attrs, context)
        else -> walk(builder, node, attrs, context)
      }
    }
  }

  private fun appendRun(
    builder: SpannableStringBuilder,
    text: String,
    attrs: ResolvedAttrs,
    context: Context,
  ) {
    if (text.isEmpty()) {
      return
    }
    val start = builder.length
    builder.append(text)
    builder.setSpan(
      RunSpan(
        typeface = buildTypeface(attrs),
        textSizePx = attrs.fontSizePx,
        color = attrs.color,
        baselineShiftPx = attrs.baselineShiftPx,
        fontFeatureSettings = attrs.variants?.let(::featureSettings),
        underline = attrs.underline,
        strikethrough = attrs.strikethrough,
        backgroundColor = attrs.backgroundColor,
      ),
      start,
      builder.length,
      Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
    )
    // context is unused here but kept for future per-run needs.
  }

  private fun buildTypeface(attrs: ResolvedAttrs): Typeface {
    val base = if (attrs.family != null) {
      Typeface.create(attrs.family, Typeface.NORMAL)
    } else {
      Typeface.DEFAULT
    }
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
      Typeface.create(base, attrs.weight, attrs.italic)
    } else {
      val style = when {
        attrs.weight >= 600 && attrs.italic -> Typeface.BOLD_ITALIC
        attrs.weight >= 600 -> Typeface.BOLD
        attrs.italic -> Typeface.ITALIC
        else -> Typeface.NORMAL
      }
      Typeface.create(base, style)
    }
  }

  private fun featureSettings(variants: List<String>): String? {
    val features = variants.mapNotNull {
      when (it) {
        "tabular-nums" -> "'tnum'"
        "proportional-nums" -> "'pnum'"
        "oldstyle-nums" -> "'onum'"
        "lining-nums" -> "'lnum'"
        "small-caps" -> "'smcp'"
        else -> null
      }
    }
    return if (features.isEmpty()) null else features.joinToString(", ")
  }
}
