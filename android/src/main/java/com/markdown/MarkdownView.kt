package com.markdown

import android.content.Context
import android.text.method.LinkMovementMethod
import android.view.View.MeasureSpec
import android.widget.TextView
import com.facebook.react.uimanager.PixelUtil
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
        // Disable extra font padding so the rendered height matches
        // the StaticLayout measurement in MarkdownMeasurer exactly.
        includeFontPadding = false
        // Prevent the TextView from scrolling internally — the user
        // wraps MarkdownView in their own ScrollView if needed.
        isVerticalScrollBarEnabled = false
        isHorizontalScrollBarEnabled = false
        overScrollMode = OVER_SCROLL_NEVER
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        // Let TextView compute its natural content height, then use
        // it regardless of Yoga's height constraint. This ensures
        // the view is never clipped — Yoga may underestimate height
        // if the custom shadow node measurement isn't active.
        val widthSpec = widthMeasureSpec
        val unconstrainedHeight = MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
        super.onMeasure(widthSpec, unconstrainedHeight)
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
        // Clear renderer cache since styles changed
        MarkdownRenderer.clearCache()
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

        // Ensure base style is applied before rendering (setMarkdown
        // can be called before setMarkdownStyle by the prop order).
        applyBaseTextStyle()

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
