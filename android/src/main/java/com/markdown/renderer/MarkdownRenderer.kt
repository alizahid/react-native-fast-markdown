package com.markdown.renderer

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.*
import android.util.LruCache
import com.markdown.parser.ASTNode
import com.markdown.styles.ElementStyle
import com.markdown.styles.StyleConfig

class MarkdownRenderer(private val context: Context) {

    companion object {
        private val cache = LruCache<String, SpannableStringBuilder>(128)
    }

    fun render(
        ast: ASTNode,
        styleConfig: StyleConfig,
        customTags: Set<String> = emptySet()
    ): SpannableStringBuilder {
        val builder = SpannableStringBuilder()
        val ctx = RenderContext(styleConfig, customTags)
        renderNode(ast, builder, ctx)

        // Trim trailing newline
        if (builder.isNotEmpty() && builder[builder.length - 1] == '\n') {
            builder.delete(builder.length - 1, builder.length)
        }

        return builder
    }

    fun renderCached(
        markdown: String,
        ast: ASTNode,
        styleConfig: StyleConfig,
        customTags: Set<String> = emptySet()
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
        ctx: RenderContext
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
            ASTNode.TEXT -> renderText(node, builder, ctx)
            ASTNode.SOFT_BREAK -> builder.append(" ")
            ASTNode.LINE_BREAK -> builder.append("\n")
            ASTNode.CODE -> renderInlineCode(node, builder, ctx)
            ASTNode.EMPHASIS -> renderEmphasis(node, builder, ctx)
            ASTNode.STRONG -> renderStrong(node, builder, ctx)
            ASTNode.STRIKETHROUGH -> renderStrikethrough(node, builder, ctx)
            ASTNode.UNDERLINE -> renderUnderline(node, builder, ctx)
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

    private fun renderParagraph(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        val start = builder.length
        val style = ctx.styleConfig.paragraph
        renderChildren(node, builder, ctx)
        applyTextStyle(builder, start, builder.length, style)
        builder.append("\n")
    }

    private fun renderHeading(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        val start = builder.length
        val style = ctx.styleConfig.styleForHeadingLevel(node.headingLevel)
        renderChildren(node, builder, ctx)

        val size = style.resolvedFontSize()
        builder.setSpan(AbsoluteSizeSpan(size.toInt(), true), start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        builder.setSpan(StyleSpan(Typeface.BOLD), start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        if (style.color != null) {
            builder.setSpan(ForegroundColorSpan(style.color), start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        builder.append("\n")
    }

    private fun renderBlockquote(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        val start = builder.length
        val style = ctx.styleConfig.blockquote
        val quoteColor = style.borderLeftColor ?: Color.GRAY

        builder.append("\u2503 ")
        renderChildren(node, builder, ctx)
        builder.setSpan(QuoteSpan(quoteColor), start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        if (style.fontStyle == "italic") {
            builder.setSpan(StyleSpan(Typeface.ITALIC), start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
    }

    private fun renderList(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        val prevDepth = ctx.listDepth
        val prevIndex = ctx.orderedListIndex
        ctx.listDepth++
        ctx.orderedListIndex = node.listStart
        renderChildren(node, builder, ctx)
        ctx.listDepth = prevDepth
        ctx.orderedListIndex = prevIndex
    }

    private fun renderListItem(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        val indent = "    ".repeat((ctx.listDepth - 1).coerceAtLeast(0))
        val bullet = when {
            node.isTask -> if (node.taskChecked) "[x] " else "[ ] "
            node.ordered -> "${ctx.orderedListIndex++}. "
            else -> {
                val bullets = listOf("\u2022 ", "\u25E6 ", "\u25AA ")
                bullets[((ctx.listDepth - 1).coerceAtLeast(0)) % bullets.size]
            }
        }

        builder.append(indent)
        builder.append(bullet)
        val style = ctx.styleConfig.listItem
        val start = builder.length
        renderChildren(node, builder, ctx)
        applyTextStyle(builder, start, builder.length, style)
    }

    private fun renderCodeBlock(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        val start = builder.length
        val style = ctx.styleConfig.codeBlock
        renderChildren(node, builder, ctx)

        builder.setSpan(TypefaceSpan("monospace"), start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        val fontSize = style.resolvedFontSize()
        if (fontSize > 0) {
            builder.setSpan(AbsoluteSizeSpan(fontSize.toInt(), true), start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        if (style.backgroundColor != null) {
            builder.setSpan(BackgroundColorSpan(style.backgroundColor), start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }

        if (builder.isNotEmpty() && builder[builder.length - 1] != '\n') {
            builder.append("\n")
        }
    }

    private fun renderThematicBreak(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        val start = builder.length
        builder.append("───────────\n")
        val color = ctx.styleConfig.thematicBreak.backgroundColor ?: Color.LTGRAY
        builder.setSpan(ForegroundColorSpan(color), start, builder.length - 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    }

    private fun renderTableRow(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        builder.append("| ")
        for ((i, cell) in node.children.withIndex()) {
            if (i > 0) builder.append(" | ")
            renderChildren(cell, builder, ctx)
        }
        builder.append(" |\n")
    }

    private fun renderText(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        builder.append(node.content)
    }

    private fun renderInlineCode(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        val start = builder.length
        val style = ctx.styleConfig.code
        renderChildren(node, builder, ctx)
        builder.setSpan(TypefaceSpan("monospace"), start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        if (style.backgroundColor != null) {
            builder.setSpan(BackgroundColorSpan(style.backgroundColor), start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
    }

    private fun renderEmphasis(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        val start = builder.length
        renderChildren(node, builder, ctx)
        builder.setSpan(StyleSpan(Typeface.ITALIC), start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    }

    private fun renderStrong(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        val start = builder.length
        renderChildren(node, builder, ctx)
        builder.setSpan(StyleSpan(Typeface.BOLD), start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    }

    private fun renderStrikethrough(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        val start = builder.length
        renderChildren(node, builder, ctx)
        builder.setSpan(StrikethroughSpan(), start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    }

    private fun renderUnderline(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        val start = builder.length
        renderChildren(node, builder, ctx)
        builder.setSpan(UnderlineSpan(), start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    }

    private fun renderLink(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        val start = builder.length
        val style = ctx.styleConfig.link
        renderChildren(node, builder, ctx)
        if (node.url.isNotEmpty()) {
            builder.setSpan(URLSpan(node.url), start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        if (style.color != null) {
            builder.setSpan(ForegroundColorSpan(style.color), start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
    }

    private fun renderImage(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        val altText = node.children
            .filter { it.type == ASTNode.TEXT }
            .joinToString("") { it.content }
            .ifEmpty { "[Image]" }
        val start = builder.length
        builder.append("[$altText]\n")
        builder.setSpan(ForegroundColorSpan(Color.GRAY), start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    }

    private fun renderCustomTag(node: ASTNode, builder: SpannableStringBuilder, ctx: RenderContext) {
        when (node.tag) {
            "Mention" -> {
                val style = ctx.styleConfig.mention
                val user = node.props["user"] ?: ""
                val start = builder.length
                builder.append("@$user")
                if (style.color != null) {
                    builder.setSpan(ForegroundColorSpan(style.color), start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                }
                val typeface = style.resolveTypeface()
                if (typeface != Typeface.DEFAULT) {
                    builder.setSpan(StyleSpan(typeface.style), start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                }
            }
            "Spoiler" -> {
                val style = ctx.styleConfig.spoiler
                val start = builder.length
                renderChildren(node, builder, ctx)
                val color = style.backgroundColor ?: Color.BLACK
                builder.setSpan(ForegroundColorSpan(color), start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                builder.setSpan(BackgroundColorSpan(color), start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            }
            else -> {
                renderChildren(node, builder, ctx)
            }
        }
    }

    private fun applyTextStyle(builder: SpannableStringBuilder, start: Int, end: Int, style: ElementStyle) {
        if (start >= end) return
        val fontSize = style.resolvedFontSize()
        if (fontSize > 0) {
            builder.setSpan(AbsoluteSizeSpan(fontSize.toInt(), true), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        if (style.color != null) {
            builder.setSpan(ForegroundColorSpan(style.color), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
    }

    private class RenderContext(
        val styleConfig: StyleConfig,
        val customTags: Set<String>,
        var listDepth: Int = 0,
        var orderedListIndex: Int = 1
    )
}
