package com.markdown

import android.content.Context
import android.text.Editable
import android.text.TextWatcher
import android.widget.EditText
import com.markdown.parser.ParserBridge
import com.markdown.renderer.MarkdownRenderer
import com.markdown.styles.StyleConfig

class MarkdownEditorView(context: Context) : EditText(context) {

    private val renderer = MarkdownRenderer(context)
    private var styleConfig = StyleConfig()
    private var customTags = listOf<String>()
    private var isUpdating = false

    // Formatting state
    var isBold = false; private set
    var isItalic = false; private set
    var isStrikethrough = false; private set
    var isCode = false; private set

    // Callbacks
    var onChangeText: ((String) -> Unit)? = null
    var onChangeMarkdown: ((String) -> Unit)? = null
    var onChangeSelection: ((Int, Int) -> Unit)? = null
    var onChangeState: (() -> Unit)? = null

    init {
        addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable?) {
                if (isUpdating) return
                applyMarkdownFormatting()
                onChangeText?.invoke(text.toString())
                onChangeMarkdown?.invoke(text.toString())
            }
        })
    }

    fun setMarkdownStyle(styleJSON: String) {
        styleConfig = StyleConfig.fromJSON(styleJSON)
        applyMarkdownFormatting()
    }

    fun setCustomTags(tags: List<String>) {
        customTags = tags
    }

    // --- Formatting toggles ---

    fun toggleBold() = toggleFormatting("**")
    fun toggleItalic() = toggleFormatting("*")
    fun toggleStrikethrough() = toggleFormatting("~~")
    fun toggleCode() = toggleFormatting("`")

    fun toggleHeading(level: Int) {
        val prefix = "#".repeat(level) + " "
        toggleLinePrefix(prefix)
    }

    fun toggleOrderedList() = toggleLinePrefix("1. ")
    fun toggleUnorderedList() = toggleLinePrefix("- ")
    fun toggleBlockquote() = toggleLinePrefix("> ")

    fun insertLink(url: String, linkText: String = "") {
        val displayText = when {
            linkText.isNotEmpty() -> linkText
            selectionStart != selectionEnd -> text.toString().substring(selectionStart, selectionEnd)
            else -> "link"
        }
        val markdown = "[$displayText]($url)"
        replaceSelection(markdown)
    }

    fun removeLink() {
        applyMarkdownFormatting()
    }

    fun insertMention(trigger: String, label: String, propsJson: String) {
        val tag = when (trigger) {
            "#" -> "ChannelMention"
            "/" -> "Command"
            else -> "UserMention"
        }
        try {
            val props = org.json.JSONObject(propsJson)
            val sb = StringBuilder("<$tag")
            sb.append(" name=\"$label\"")
            val keys = props.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                sb.append(" $key=\"${props.getString(key)}\"")
            }
            sb.append(" />")
            replaceSelection(sb.toString())
        } catch (_: Exception) {
            replaceSelection("<$tag name=\"$label\" />")
        }
    }

    fun insertSpoiler() {
        wrapSelection("<Spoiler>", "</Spoiler>")
    }

    fun insertCustomTag(tag: String, propsJSON: String) {
        try {
            val props = org.json.JSONObject(propsJSON)
            val sb = StringBuilder("<$tag")
            val keys = props.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                sb.append(" $key=\"${props.getString(key)}\"")
            }
            sb.append(" />")
            replaceSelection(sb.toString())
        } catch (_: Exception) {
            replaceSelection("<$tag />")
        }
    }

    // --- Internal ---

    private fun toggleFormatting(marker: String) {
        val start = selectionStart
        val end = selectionEnd

        if (start == end) {
            val insertion = "$marker$marker"
            text.insert(start, insertion)
            setSelection(start + marker.length)
        } else {
            val selected = text.toString().substring(start, end)
            if (selected.startsWith(marker) && selected.endsWith(marker) &&
                selected.length > marker.length * 2) {
                val unformatted = selected.substring(marker.length, selected.length - marker.length)
                text.replace(start, end, unformatted)
            } else {
                text.replace(start, end, "$marker$selected$marker")
            }
        }
        applyMarkdownFormatting()
    }

    private fun toggleLinePrefix(prefix: String) {
        val lineStart = text.toString().lastIndexOf('\n', selectionStart - 1) + 1
        val lineEnd = text.toString().indexOf('\n', selectionStart).let {
            if (it == -1) text.length else it
        }
        val line = text.toString().substring(lineStart, lineEnd)

        if (line.startsWith(prefix)) {
            text.replace(lineStart, lineEnd, line.removePrefix(prefix))
        } else {
            text.replace(lineStart, lineEnd, "$prefix$line")
        }
        applyMarkdownFormatting()
    }

    private fun wrapSelection(prefix: String, suffix: String) {
        val start = selectionStart
        val end = selectionEnd

        if (start == end) {
            text.insert(start, "$prefix$suffix")
            setSelection(start + prefix.length)
        } else {
            val selected = text.toString().substring(start, end)
            text.replace(start, end, "$prefix$selected$suffix")
        }
        applyMarkdownFormatting()
    }

    private fun replaceSelection(replacement: String) {
        val start = selectionStart
        val end = selectionEnd
        text.replace(start, end, replacement)
        applyMarkdownFormatting()
    }

    private fun applyMarkdownFormatting() {
        if (isUpdating) return
        isUpdating = true
        try {
            val markdown = text.toString()
            if (markdown.isEmpty()) return

            val savedStart = selectionStart
            val savedEnd = selectionEnd

            val ast = ParserBridge.parse(markdown, customTags)
            val spannable = renderer.render(ast, styleConfig, customTags.toSet())

            // For now, we keep the raw markdown and apply visual formatting
            // A more complete implementation would sync formatted output
            // with source markdown character positions

            isUpdating = false

            if (savedStart <= text.length && savedEnd <= text.length) {
                setSelection(savedStart, savedEnd)
            }

            detectFormattingState()
        } finally {
            isUpdating = false
        }
    }

    private fun detectFormattingState() {
        val pos = selectionStart
        val txt = text.toString()

        isBold = isInsideMarker("**", txt, pos)
        isItalic = isInsideMarker("*", txt, pos) && !isBold
        isStrikethrough = isInsideMarker("~~", txt, pos)
        isCode = isInsideMarker("`", txt, pos)

        onChangeState?.invoke()
    }

    private fun isInsideMarker(marker: String, text: String, pos: Int): Boolean {
        val before = text.lastIndexOf(marker, pos - 1)
        if (before == -1) return false

        val searchStart = before + marker.length
        if (searchStart >= text.length) return false

        val after = text.indexOf(marker, searchStart)
        if (after == -1) return false

        return pos > before && pos <= after
    }

    override fun onSelectionChanged(selStart: Int, selEnd: Int) {
        super.onSelectionChanged(selStart, selEnd)
        onChangeSelection?.invoke(selStart, selEnd)
        detectFormattingState()
    }
}
