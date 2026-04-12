package com.markdown

import android.content.Context
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
        // Configure as non-editable display text
        isFocusable = false
        isClickable = false
        setTextIsSelectable(false)
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
        renderMarkdown()
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
        // Built-in custom tags — always recognized so users don't have to
        // register them via the customTags prop. Matches iOS MarkdownView.
        val builtInTags = listOf("UserMention", "ChannelMention", "Command", "Spoiler")
        val effectiveTags = (builtInTags + customTags).distinct()
        val tags = effectiveTags.toSet()

        // Short content: render synchronously
        if (markdown.length < 500) {
            val ast = ParserBridge.parse(markdown, effectiveTags)
            val spannable = renderer.renderCached(markdown, ast, config, tags)
            text = spannable
            return
        }

        // Longer content: render on background thread
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
