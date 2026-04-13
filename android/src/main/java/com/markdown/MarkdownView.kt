package com.markdown

import android.content.Context
import android.text.method.LinkMovementMethod
import android.widget.TextView
import com.markdown.parser.ParserBridge
import com.markdown.renderer.MarkdownRenderer
import com.markdown.styles.StyleConfig
import java.util.concurrent.Executors

class MarkdownView(context: Context) : TextView(context) {

    private val renderer = MarkdownRenderer(context)
    private val executor = Executors.newSingleThreadExecutor()

    private var currentMarkdown: String = ""
    private var currentStyleJSON: String = ""
    private var customTags: List<String> = emptyList()
    private var styleConfig: StyleConfig = StyleConfig()

    init {
        isFocusable = false
        isClickable = false
        setTextIsSelectable(false)
        movementMethod = LinkMovementMethod.getInstance()
        highlightColor = 0
        // Prevent the TextView from scrolling internally — the user
        // wraps MarkdownView in their own ScrollView if needed.
        isVerticalScrollBarEnabled = false
        isHorizontalScrollBarEnabled = false
        overScrollMode = OVER_SCROLL_NEVER
    }

    override fun scrollTo(x: Int, y: Int) {
        // No-op — block internal scrolling that LinkMovementMethod
        // triggers when clicking links near the bottom.
    }

    fun setMarkdown(markdown: String) {
        if (markdown == currentMarkdown) return
        currentMarkdown = markdown
        renderMarkdown()
    }

    fun setMarkdownStyle(styleJSON: String) {
        if (styleJSON == currentStyleJSON) return
        currentStyleJSON = styleJSON
        styleConfig = StyleConfig.fromJSON(styleJSON)
        applyBaseTextStyle()
        renderMarkdown()
    }

    private fun applyBaseTextStyle() {
        val base = styleConfig.base
        textSize = base.resolvedFontSize()
        if (base.color != null) {
            setTextColor(base.color)
        }
        typeface = base.resolveTypeface()
        if (base.lineHeight > 0) {
            val lineHeightPx = base.lineHeight * resources.displayMetrics.density
            val fontHeight = paint.getFontMetricsInt(null).toFloat()
            if (lineHeightPx > fontHeight) {
                setLineSpacing(lineHeightPx - fontHeight, 1f)
            }
        }
    }

    fun setCustomTags(tags: List<String>) {
        customTags = tags
    }

    private fun renderMarkdown() {
        if (currentMarkdown.isEmpty()) {
            text = ""
            return
        }

        val markdown = currentMarkdown
        val config = styleConfig
        val builtInTags = listOf("UserMention", "ChannelMention", "Command", "Spoiler")
        val effectiveTags = (builtInTags + customTags).distinct()
        val tags = effectiveTags.toSet()

        if (markdown.length < 500) {
            val ast = ParserBridge.parse(markdown, effectiveTags)
            val spannable = renderer.renderCached(markdown, ast, config, tags)
            text = spannable
            return
        }

        executor.execute {
            val ast = ParserBridge.parse(markdown, effectiveTags)
            val spannable = renderer.renderCached(markdown, ast, config, tags)
            post {
                if (markdown == currentMarkdown) {
                    text = spannable
                }
            }
        }
    }
}
