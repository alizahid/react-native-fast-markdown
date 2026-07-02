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
import com.fastmarkdown.style.LayoutStyleSpec
import com.fastmarkdown.style.StyleConfig
import com.fastmarkdown.style.TextStyleSpec
import org.json.JSONObject

/**
 * AST -> renderable block tree. Inline runs carry one RunSpan each with the
 * fully-resolved attributes (mirrors the iOS attribute-stack renderer).
 */
object SpannableRenderer {
  private const val DEFAULT_LINK_COLOR = 0xFF007AFF.toInt()
  private const val DEFAULT_CODE_BACKGROUND = 0x14000000
  private const val DEFAULT_QUOTE_BORDER = 0x33000000
  private const val DEFAULT_DIVIDER_COLOR = 0x22000000
  private const val DEFAULT_MARKER_WIDTH_DP = 24f

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

    fun layoutStyle(key: String, defaults: LayoutStyleSpec): LayoutStyleSpec {
      val spec = LayoutStyleSpec.from(styles.rawSection(key), defaults)
      return spec.scaled(density)
    }
  }

  fun render(root: MdNode, styles: StyleConfig, density: Float, fontScale: Float): List<Block> {
    val context = Context(styles, density, fontScale)
    return renderBlocks(root.children, context, inherited = null)
  }

  // Coalesces stray inline children (tight list items) into paragraphs and
  // renders each block child.
  private fun renderBlocks(
    children: List<MdNode>,
    context: Context,
    inherited: TextStyleSpec?,
  ): List<Block> {
    val out = ArrayList<Block>()
    var inlineRun = ArrayList<MdNode>()

    fun flushInline() {
      if (inlineRun.isNotEmpty()) {
        val synthetic = MdNode(MdNodeType.PARAGRAPH, "", "", 0, false, 1, inlineRun)
        out.add(textBlock(synthetic, context, inherited))
        inlineRun = ArrayList()
      }
    }

    for (child in children) {
      if (isInline(child.type)) {
        inlineRun.add(child)
      } else {
        flushInline()
        renderBlock(child, context, inherited, out)
      }
    }
    flushInline()
    return out
  }

  private fun isInline(type: MdNodeType): Boolean = when (type) {
    MdNodeType.TEXT, MdNodeType.SOFT_BREAK, MdNodeType.HARD_BREAK, MdNodeType.BOLD,
    MdNodeType.ITALIC, MdNodeType.STRIKETHROUGH, MdNodeType.LINK, MdNodeType.INLINE_CODE,
    MdNodeType.SPOILER, MdNodeType.SUPERSCRIPT, MdNodeType.SUBSCRIPT, MdNodeType.IMAGE,
    -> true
    else -> false
  }

  private fun renderBlock(
    node: MdNode,
    context: Context,
    inherited: TextStyleSpec?,
    out: MutableList<Block>,
  ) {
    when (node.type) {
      MdNodeType.PARAGRAPH, MdNodeType.HEADING ->
        out.add(textBlock(node, context, inherited))

      MdNodeType.BLOCK_QUOTE -> {
        val defaults = LayoutStyleSpec(
          backgroundColor = null,
          paddingLeft = 12f, paddingRight = 0f, paddingTop = 0f, paddingBottom = 0f,
          borderRadius = 0f,
          borderLeftColor = DEFAULT_QUOTE_BORDER, borderLeftWidth = 3f,
          borderRightColor = null, borderRightWidth = 0f,
          borderTopColor = null, borderTopWidth = 0f,
          borderBottomColor = null, borderBottomWidth = 0f,
        )
        val layout = context.layoutStyle("blockQuote", defaults)
        val quoteText = merge(inherited, context.styles.textStyleFor("blockQuote"))
        out.add(Block.Quote(renderBlocks(node.children, context, quoteText), layout))
      }

      MdNodeType.CODE_BLOCK -> {
        val defaults = LayoutStyleSpec(
          backgroundColor = DEFAULT_CODE_BACKGROUND,
          paddingLeft = 12f, paddingRight = 12f, paddingTop = 12f, paddingBottom = 12f,
          borderRadius = 6f,
          borderLeftColor = null, borderLeftWidth = 0f,
          borderRightColor = null, borderRightWidth = 0f,
          borderTopColor = null, borderTopWidth = 0f,
          borderBottomColor = null, borderBottomWidth = 0f,
        )
        val layout = context.layoutStyle("codeBlock", defaults)
        var attrs = ResolvedAttrs(
          fontSizePx = 14f * context.density * context.fontScale,
          family = "monospace",
        )
        attrs = context.apply(attrs, inherited)
        attrs = context.apply(attrs, "codeBlock")
        val text = SpannableStringBuilder()
        appendRun(text, node.text.trimEnd('\n'), attrs)
        out.add(Block.Code(text, basePaint(attrs), layout))
      }

      MdNodeType.LIST -> out.add(listBlock(node, context, inherited))

      MdNodeType.THEMATIC_BREAK ->
        out.add(Block.Divider(DEFAULT_DIVIDER_COLOR, 1f * context.density))

      else -> {
        if (node.children.isNotEmpty()) {
          out.addAll(renderBlocks(node.children, context, inherited))
        } else if (node.text.isNotEmpty()) {
          val synthetic = MdNode(
            MdNodeType.PARAGRAPH, "", "", 0, false, 1,
            listOf(MdNode(MdNodeType.TEXT, node.text, "", 0, false, 1, emptyList())),
          )
          out.add(textBlock(synthetic, context, inherited))
        }
      }
    }
  }

  private fun listBlock(node: MdNode, context: Context, inherited: TextStyleSpec?): Block.ListBlock {
    val styles = context.styles
    val listSection = styles.rawSection("list")
    val markerSection = styles.rawSection("listMarker")

    val marginLeft = (listSection?.optDpOr("marginLeft", 0f) ?: 0f) * context.density
    val markerWidth =
      (markerSection?.optDpOr("width", DEFAULT_MARKER_WIDTH_DP) ?: DEFAULT_MARKER_WIDTH_DP) * context.density
    val markerMarginLeft = (markerSection?.optDpOr("marginLeft", 0f) ?: 0f) * context.density
    val markerColor = markerSection?.let { TextStyleSpec.from(it)?.color }

    val itemText = merge(inherited, styles.textStyleFor("listItem"))

    var markerAttrs = ResolvedAttrs(fontSizePx = styles.fontSize(0) * context.density * context.fontScale)
    markerAttrs = context.apply(markerAttrs, "paragraph")
    markerAttrs = context.apply(markerAttrs, itemText)
    if (markerColor != null) {
      markerAttrs = markerAttrs.copy(color = markerColor)
    }

    val rows = ArrayList<Block.ListRow>()
    var index = node.startIndex
    for (item in node.children) {
      if (item.type != MdNodeType.LIST_ITEM) {
        continue
      }
      val markerText = if (node.ordered) "$index." else "•"
      val marker = SpannableStringBuilder()
      appendRun(marker, markerText, markerAttrs)
      rows.add(
        Block.ListRow(
          marker = marker,
          markerPaint = basePaint(markerAttrs),
          content = renderBlocks(item.children, context, itemText),
        )
      )
      index++
    }
    return Block.ListBlock(rows, marginLeft, markerWidth, markerMarginLeft)
  }

  private fun merge(base: TextStyleSpec?, over: TextStyleSpec?): TextStyleSpec? {
    if (base == null) {
      return over
    }
    if (over == null) {
      return base
    }
    return TextStyleSpec(
      fontSize = over.fontSize ?: base.fontSize,
      fontWeight = over.fontWeight ?: base.fontWeight,
      fontFamily = over.fontFamily ?: base.fontFamily,
      color = over.color ?: base.color,
      fontVariant = over.fontVariant ?: base.fontVariant,
      textDecorationColor = over.textDecorationColor ?: base.textDecorationColor,
      textDecorationLine = over.textDecorationLine ?: base.textDecorationLine,
      textDecorationStyle = over.textDecorationStyle ?: base.textDecorationStyle,
      backgroundColor = over.backgroundColor ?: base.backgroundColor,
    )
  }

  private fun textBlock(node: MdNode, context: Context, inherited: TextStyleSpec?): Block.Text {
    val builder = SpannableStringBuilder()
    val attrs = baseAttrs(node, context, inherited)
    walk(builder, node, attrs, context)
    return Block.Text(builder, basePaint(attrs))
  }

  private fun basePaint(attrs: ResolvedAttrs): TextPaint = TextPaint().apply {
    isAntiAlias = true
    textSize = attrs.fontSizePx
  }

  private fun baseAttrs(node: MdNode, context: Context, inherited: TextStyleSpec?): ResolvedAttrs {
    val styles = context.styles
    val scale = context.density * context.fontScale
    var attrs: ResolvedAttrs
    if (node.type == MdNodeType.HEADING) {
      attrs = ResolvedAttrs(fontSizePx = styles.fontSize(node.level) * scale, weight = 700)
      attrs = context.apply(attrs, inherited)
      attrs = context.apply(attrs, "h${node.level}")
    } else {
      attrs = ResolvedAttrs(fontSizePx = styles.fontSize(0) * scale)
      attrs = context.apply(attrs, "paragraph")
      attrs = context.apply(attrs, inherited)
    }
    return attrs
  }

  private fun walk(
    builder: SpannableStringBuilder,
    parent: MdNode,
    attrs: ResolvedAttrs,
    context: Context,
  ) {
    for (node in parent.children) {
      when (node.type) {
        MdNodeType.TEXT -> appendRun(builder, node.text, attrs)
        MdNodeType.SOFT_BREAK -> appendRun(builder, " ", attrs)
        MdNodeType.HARD_BREAK -> appendRun(builder, "\n", attrs)
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
          appendRun(builder, node.text, next)
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
        MdNodeType.IMAGE -> appendRun(builder, node.text, attrs)
        else -> walk(builder, node, attrs, context)
      }
    }
  }

  private fun appendRun(builder: SpannableStringBuilder, text: String, attrs: ResolvedAttrs) {
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

  private fun JSONObject.optDpOr(key: String, fallback: Float): Float {
    val value = optDouble(key)
    return if (value.isNaN()) fallback else value.toFloat()
  }
}
