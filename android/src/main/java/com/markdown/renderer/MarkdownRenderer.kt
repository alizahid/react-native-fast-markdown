package com.markdown.renderer

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.*
import android.util.LruCache
import com.markdown.parser.ASTNode
import com.markdown.renderer.spans.BlockBackgroundSpan
import com.markdown.renderer.spans.BlockQuoteSpan
import com.markdown.renderer.spans.CustomLineHeightSpan
import com.markdown.renderer.spans.LetterSpacingSpan
import com.markdown.styles.ElementStyle
import com.markdown.styles.StyleConfig
import kotlin.math.roundToInt

class MarkdownRenderer(private val context: Context) {

    companion object {
        private val cache = LruCache<String, SpannableStringBuilder>(128)
    }

    private val density = context.resources.displayMetrics.density

    private fun dp(value: Float): Float = value * density
    private fun dpInt(value: Float): Int = (value * density).roundToInt()

    fun render(
        ast: ASTNode,
        styleConfig: StyleConfig,
        customTags: Set<String> = emptySet(),
    ): SpannableStringBuilder {
        val builder = SpannableStringBuilder()
        val ctx = RenderContext(styleConfig, customTags)
        renderNode(ast, builder, ctx)

        // Trim trailing newlines
        while (builder.isNotEmpty() && builder[builder.length - 1] == '\n') {
            builder.delete(builder.length - 1, builder.length)
        }

        return builder
    }

    fun renderCached(
        markdown: String,
        ast: ASTNode,
        styleConfig: StyleConfig,
        customTags: Set<String> = emptySet(),
    ): SpannableStringBuilder {
        val cached = cache.get(markdown)
        if (cached != null) return SpannableStringBuilder(cached)

        val result = render(ast, styleConfig, customTags)
        cache.put(markdown, SpannableStringBuilder(result))
        return result
    }

    private fun renderNode(
        node: ASTNode,
        builder: SpannableStringBuilder,
        ctx: RenderContext,
    ) {
        when (node.type) {
            ASTNode.DOCUMENT -> renderChildren(node, builder, ctx)
            ASTNode.PARAGRAPH -> renderParagraph(node, builder, ctx)
            ASTNode.HEADING -> renderHeading(node, builder, ctx)
            ASTNode.BLOCKQUOTE -> renderBlockquote(node, builder, ctx)
            ASTNode.LIST -> renderList(node, builder, ctx)
            ASTNode.LIST_ITEM -> renderListItem(node, builder, ctx)
            ASTNode.CODE_BLOCK -> renderCodeBlock(node, builder, ctx)
            ASTNode.THEMATIC_BREAK -> renderThematicBreak(node, builder, ctx)
            ASTNode.TABLE, ASTNode.TABLE_HEAD, ASTNode.TABLE_BODY -> renderChildren(node, builder, ctx)
            ASTNode.TABLE_ROW -> renderTableRow(node, builder, ctx)
            ASTNode.TABLE_CELL -> renderChildren(node, builder, ctx)
            ASTNode.TEXT -> builder.append(node.content)
            ASTNode.SOFT_BREAK -> builder.append(" ")
            ASTNode.LINE_BREAK -> builder.append("\n")
            ASTNode.CODE -> renderInlineCode(node, builder, ctx)
            ASTNode.EMPHASIS -> renderEmphasis(node, builder, ctx)
            ASTNode.STRONG -> renderStrong(node, builder, ctx)
            ASTNode.STRIKETHROUGH -> renderStrikethrough(node, builder, ctx)
            ASTNode.LINK -> renderLink(node, builder, ctx)
            ASTNode.IMAGE -> renderImage(node, builder, ctx)
            ASTNode.CUSTOM_TAG -> renderCustomTag(node, builder, ctx)
            else -> renderChildren(node, builder, ctx)
        }
    }

    private fun renderChildren(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        for (child in node.children) {
            renderNode(child, builder, ctx)
        }
    }

    // ── Block-level rendering ──────────────────────────────────────

    private fun renderParagraph(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        ensureBlockSeparator(builder)
        val start = builder.length
        val style = ctx.styleConfig.paragraph
        renderChildren(node, builder, ctx)
        applyElementStyle(builder, start, builder.length, style)
    }

    private fun renderHeading(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        ensureBlockSeparator(builder)
        val start = builder.length
        val style = ctx.styleConfig.styleForHeadingLevel(node.headingLevel)
        renderChildren(node, builder, ctx)

        val end = builder.length
        val size = style.resolvedFontSize()
        builder.setSpan(AbsoluteSizeSpan(size.toInt(), true), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        builder.setSpan(StyleSpan(Typeface.BOLD), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        if (style.color != null) {
            builder.setSpan(ForegroundColorSpan(style.color), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        if (style.lineHeight > 0) {
            builder.setSpan(CustomLineHeightSpan(dpInt(style.lineHeight)), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
    }

    private fun renderCodeBlock(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        ensureBlockSeparator(builder)
        val start = builder.length
        val style = ctx.styleConfig.codeBlock
        renderChildren(node, builder, ctx)

        // Trim trailing newline inside code block
        if (builder.length > start && builder[builder.length - 1] == '\n') {
            builder.delete(builder.length - 1, builder.length)
        }

        val end = builder.length

        builder.setSpan(TypefaceSpan("monospace"), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        val fontSize = style.resolvedFontSize()
        if (style.fontSize > 0) {
            builder.setSpan(AbsoluteSizeSpan(fontSize.toInt(), true), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        if (style.color != null) {
            builder.setSpan(ForegroundColorSpan(style.color), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }

        // Block background with padding, border, radius
        if (style.backgroundColor != null || style.hasAnyBorder()) {
            builder.setSpan(
                BlockBackgroundSpan(
                    backgroundColor = style.backgroundColor ?: Color.TRANSPARENT,
                    borderRadius = dp(style.borderRadius),
                    paddingLeft = dp(style.resolvedPaddingLeft()),
                    paddingRight = dp(style.resolvedPaddingRight()),
                    paddingTop = dp(style.resolvedPaddingTop()),
                    paddingBottom = dp(style.resolvedPaddingBottom()),
                    borderLeftWidth = dp(style.resolvedBorderLeftWidth()),
                    borderLeftColor = style.resolvedBorderLeftColor() ?: Color.TRANSPARENT,
                    borderTopWidth = dp(style.resolvedBorderTopWidth()),
                    borderTopColor = style.resolvedBorderTopColor() ?: Color.TRANSPARENT,
                    borderRightWidth = dp(style.resolvedBorderRightWidth()),
                    borderRightColor = style.resolvedBorderRightColor() ?: Color.TRANSPARENT,
                    borderBottomWidth = dp(style.resolvedBorderBottomWidth()),
                    borderBottomColor = style.resolvedBorderBottomColor() ?: Color.TRANSPARENT,
                ),
                start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
            )
        }
    }

    private fun renderBlockquote(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        ensureBlockSeparator(builder)
        val start = builder.length
        val style = ctx.styleConfig.blockquote

        val barColor = style.resolvedBorderLeftColor() ?: style.borderColor ?: Color.GRAY
        val barWidth = dp(if (style.resolvedBorderLeftWidth() > 0) style.resolvedBorderLeftWidth() else 3f)
        val gapWidth = dp(if (style.resolvedPaddingLeft() > 0) style.resolvedPaddingLeft() else 8f)

        // Save and update blockquote nesting
        val prevNesting = ctx.blockquoteNesting
        ctx.blockquoteNesting++

        renderChildren(node, builder, ctx)

        ctx.blockquoteNesting = prevNesting

        val end = builder.length

        builder.setSpan(
            BlockQuoteSpan(
                barColor = barColor,
                barWidth = barWidth,
                gapWidth = gapWidth,
                backgroundColor = style.backgroundColor,
                nestingLevel = prevNesting,
            ),
            start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
        )

        if (style.fontStyle == "italic") {
            builder.setSpan(StyleSpan(Typeface.ITALIC), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        if (style.color != null) {
            builder.setSpan(ForegroundColorSpan(style.color), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
    }

    private fun renderList(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        val prevDepth = ctx.listDepth
        val prevIndex = ctx.orderedListIndex
        val prevOrdered = ctx.currentListIsOrdered
        val prevMaxDigits = ctx.currentListMaxMarkerDigits

        ctx.listDepth++
        ctx.currentListIsOrdered = node.ordered
        ctx.orderedListIndex = node.listStart

        // Compute max marker digits for aligned numbering
        if (node.ordered) {
            var itemCount = 0
            for (child in node.children) {
                if (child.type == ASTNode.LIST_ITEM) itemCount++
            }
            val lastNumber = maxOf(1, node.listStart + itemCount - 1)
            ctx.currentListMaxMarkerDigits = lastNumber.toString().length
        }

        renderChildren(node, builder, ctx)

        ctx.listDepth = prevDepth
        ctx.orderedListIndex = prevIndex
        ctx.currentListIsOrdered = prevOrdered
        ctx.currentListMaxMarkerDigits = prevMaxDigits
    }

    private fun renderListItem(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        val style = ctx.styleConfig.listItem
        val bulletStyle = ctx.styleConfig.listBullet

        // Ensure each item starts on its own line
        if (builder.isNotEmpty() && builder[builder.length - 1] != '\n') {
            builder.append("\n")
        }

        // Indent for nesting
        val indent = "    ".repeat((ctx.listDepth - 1).coerceAtLeast(0))

        // Build bullet/number prefix
        val bullet: String = when {
            node.isTask -> if (node.taskChecked) "\u2611 " else "\u2610 "
            ctx.currentListIsOrdered -> {
                val number = ctx.orderedListIndex
                val digits = number.toString().length
                val padCount = (ctx.currentListMaxMarkerDigits - digits).coerceAtLeast(0)
                // U+2007 = figure space (digit-width whitespace for alignment)
                val padding = "\u2007".repeat(padCount)
                ctx.orderedListIndex++
                "$padding$number. "
            }
            else -> {
                val bullets = listOf("\u2022 ", "\u25E6 ", "\u25AA ")
                bullets[((ctx.listDepth - 1).coerceAtLeast(0)) % bullets.size]
            }
        }

        val prefix = "$indent$bullet"

        // Append bullet with its own style
        val bulletStart = builder.length
        builder.append(prefix)
        val bulletEnd = builder.length
        if (bulletStyle.color != null) {
            builder.setSpan(ForegroundColorSpan(bulletStyle.color), bulletStart, bulletEnd, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }

        // Append item content
        val contentStart = builder.length
        renderChildren(node, builder, ctx)
        applyElementStyle(builder, contentStart, builder.length, style)

        // Ensure trailing newline
        if (builder.isNotEmpty() && builder[builder.length - 1] != '\n') {
            builder.append("\n")
        }
    }

    private fun renderThematicBreak(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        ensureBlockSeparator(builder)
        val style = ctx.styleConfig.thematicBreak
        val start = builder.length
        // Use a thin line of block chars — the BlockBackgroundSpan will draw the actual line
        builder.append("\u200B") // zero-width space as content anchor
        val end = builder.length

        val color = style.backgroundColor ?: Color.LTGRAY
        val height = if (style.height > 0) dp(style.height) else dp(1f)

        builder.setSpan(
            BlockBackgroundSpan(
                backgroundColor = color,
                paddingTop = height / 2f,
                paddingBottom = height / 2f,
            ),
            start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
        )
    }

    private fun renderTableRow(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        builder.append("| ")
        for ((i, cell) in node.children.withIndex()) {
            if (i > 0) builder.append(" | ")
            renderChildren(cell, builder, ctx)
        }
        builder.append(" |\n")
    }

    // ── Inline rendering ───────────────────────────────────────────

    private fun renderStrong(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        val start = builder.length
        renderChildren(node, builder, ctx)
        builder.setSpan(StyleSpan(Typeface.BOLD), start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        val style = ctx.styleConfig.strong
        if (style.color != null) {
            builder.setSpan(ForegroundColorSpan(style.color), start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
    }

    private fun renderEmphasis(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        val start = builder.length
        renderChildren(node, builder, ctx)
        builder.setSpan(StyleSpan(Typeface.ITALIC), start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        val style = ctx.styleConfig.emphasis
        if (style.color != null) {
            builder.setSpan(ForegroundColorSpan(style.color), start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
    }

    private fun renderStrikethrough(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        val start = builder.length
        renderChildren(node, builder, ctx)
        builder.setSpan(StrikethroughSpan(), start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        val style = ctx.styleConfig.strikethrough
        if (style.color != null) {
            builder.setSpan(ForegroundColorSpan(style.color), start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
    }

    private fun renderInlineCode(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        val start = builder.length
        val style = ctx.styleConfig.code
        renderChildren(node, builder, ctx)
        val end = builder.length
        builder.setSpan(TypefaceSpan("monospace"), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        if (style.backgroundColor != null) {
            builder.setSpan(BackgroundColorSpan(style.backgroundColor), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        if (style.color != null) {
            builder.setSpan(ForegroundColorSpan(style.color), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        if (style.fontSize > 0) {
            builder.setSpan(AbsoluteSizeSpan(style.resolvedFontSize().toInt(), true), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
    }

    private fun renderLink(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        val start = builder.length
        val style = ctx.styleConfig.link
        renderChildren(node, builder, ctx)
        val end = builder.length
        if (node.url.isNotEmpty()) {
            builder.setSpan(URLSpan(node.url), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        if (style.color != null) {
            builder.setSpan(ForegroundColorSpan(style.color), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        if (style.textDecorationLine == "underline") {
            builder.setSpan(UnderlineSpan(), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
    }

    private fun renderImage(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        val altText = node.children
            .filter { it.type == ASTNode.TEXT }
            .joinToString("") { it.content }
            .ifEmpty { "Image" }
        val start = builder.length
        builder.append("[$altText]")
        builder.setSpan(ForegroundColorSpan(Color.GRAY), start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    }

    // ── Custom tags ────────────────────────────────────────────────

    private fun renderCustomTag(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        when (node.tag) {
            "UserMention" -> renderMention(node, builder, ctx.styleConfig.mentionUser, "@")
            "ChannelMention" -> renderMention(node, builder, ctx.styleConfig.mentionChannel, "#")
            "Command" -> renderMention(node, builder, ctx.styleConfig.mentionCommand, "/")
            "Spoiler" -> renderSpoiler(node, builder, ctx)
            else -> renderChildren(node, builder, ctx)
        }
    }

    private fun renderMention(
        node: ASTNode,
        builder: SpannableStringBuilder,
        style: ElementStyle,
        prefix: String,
    ) {
        val id = node.props["id"] ?: ""
        val name = node.props["name"] ?: ""
        val label = name.ifEmpty { id }
        val start = builder.length
        builder.append(prefix).append(label)
        val end = builder.length
        if (style.color != null) {
            builder.setSpan(ForegroundColorSpan(style.color), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        if (style.backgroundColor != null) {
            builder.setSpan(BackgroundColorSpan(style.backgroundColor), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        val typeface = style.resolveTypeface()
        if (typeface != Typeface.DEFAULT) {
            builder.setSpan(StyleSpan(typeface.style), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
    }

    private fun renderSpoiler(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        val style = ctx.styleConfig.spoiler
        val start = builder.length
        renderChildren(node, builder, ctx)
        val end = builder.length
        // Hide text by matching foreground to background
        val color = style.backgroundColor ?: Color.BLACK
        builder.setSpan(ForegroundColorSpan(color), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        builder.setSpan(BackgroundColorSpan(color), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    }

    // ── Style helpers ──────────────────────────────────────────────

    private fun applyElementStyle(
        builder: SpannableStringBuilder,
        start: Int,
        end: Int,
        style: ElementStyle,
    ) {
        if (start >= end) return

        if (style.fontSize > 0) {
            builder.setSpan(AbsoluteSizeSpan(style.resolvedFontSize().toInt(), true), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        if (style.color != null) {
            builder.setSpan(ForegroundColorSpan(style.color), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        if (style.backgroundColor != null) {
            builder.setSpan(BackgroundColorSpan(style.backgroundColor), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        if (style.lineHeight > 0) {
            builder.setSpan(CustomLineHeightSpan(dpInt(style.lineHeight)), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        if (style.letterSpacing > 0) {
            builder.setSpan(LetterSpacingSpan(style.letterSpacing), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        if (style.textAlign != null) {
            val alignment = when (style.textAlign) {
                "center" -> android.text.Layout.Alignment.ALIGN_CENTER
                "right" -> android.text.Layout.Alignment.ALIGN_OPPOSITE
                else -> android.text.Layout.Alignment.ALIGN_NORMAL
            }
            builder.setSpan(AlignmentSpan.Standard(alignment), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        if (style.textDecorationLine != null) {
            when (style.textDecorationLine) {
                "underline" -> builder.setSpan(UnderlineSpan(), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                "line-through" -> builder.setSpan(StrikethroughSpan(), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                "underline line-through" -> {
                    builder.setSpan(UnderlineSpan(), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                    builder.setSpan(StrikethroughSpan(), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                }
            }
        }
        if (style.fontWeight == "bold" || style.fontWeight == "600" || style.fontWeight == "700") {
            builder.setSpan(StyleSpan(Typeface.BOLD), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        if (style.fontStyle == "italic") {
            builder.setSpan(StyleSpan(Typeface.ITALIC), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        if (style.fontFamily == "monospace" || style.fontFamily == "Menlo") {
            builder.setSpan(TypefaceSpan("monospace"), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
    }

    /**
     * Ensure there's a blank line between block elements.
     * Uses \n as separator between blocks.
     */
    private fun ensureBlockSeparator(builder: SpannableStringBuilder) {
        if (builder.isEmpty()) return
        val last = builder[builder.length - 1]
        if (last != '\n') {
            builder.append("\n")
        }
    }

    // ── Render context ─────────────────────────────────────────────

    private class RenderContext(
        val styleConfig: StyleConfig,
        val customTags: Set<String>,
        var listDepth: Int = 0,
        var orderedListIndex: Int = 1,
        var currentListIsOrdered: Boolean = false,
        var currentListMaxMarkerDigits: Int = 1,
        var blockquoteNesting: Int = 0,
    )
}
