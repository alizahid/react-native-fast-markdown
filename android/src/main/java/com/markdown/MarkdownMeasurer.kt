package com.markdown

import android.text.StaticLayout
import android.text.TextPaint
import com.markdown.parser.ParserBridge
import com.markdown.renderer.MarkdownRenderer
import com.markdown.styles.StyleConfig

/**
 * Measures markdown content height without needing a View. Called
 * from the C++ shadow node via JNI on the Yoga layout thread so
 * Fabric can size the view correctly on the first pass — no layout
 * shift, no JS round trip.
 *
 * Mirrors iOS MarkdownMeasurer.
 */
object MarkdownMeasurer {

    private val textPaint = TextPaint().apply {
        isAntiAlias = true
    }

    /**
     * Measure markdown content. Returns [width, height] as floats
     * in density-independent pixels.
     * Called from JNI (MarkdownViewShadowNode).
     */
    @JvmStatic
    fun measure(
        markdown: String,
        stylesJSON: String,
        customTagsCsv: String,
        width: Float,
        density: Float,
    ): FloatArray {
        if (markdown.isEmpty()) return floatArrayOf(width, 0f)

        val styleConfig = StyleConfig.fromJSON(stylesJSON)
        val builtInTags = listOf("UserMention", "ChannelMention", "Command", "Spoiler")
        val userTags = if (customTagsCsv.isEmpty()) emptyList()
            else customTagsCsv.split(",").filter { it.isNotEmpty() }
        val effectiveTags = (builtInTags + userTags).distinct()

        val ast = ParserBridge.parse(markdown, effectiveTags)

        val renderer = MarkdownRenderer.createForMeasurement(density)
        val spannable = renderer.render(ast, styleConfig, effectiveTags.toSet())

        val widthPx = (width * density).toInt().coerceAtLeast(1)

        synchronized(textPaint) {
            val base = styleConfig.base
            textPaint.textSize = base.resolvedFontSize() * density
            textPaint.typeface = base.resolveTypeface()

            // Compute line spacing to match what applyBaseTextStyle()
            // sets on the real TextView via setLineSpacing().
            var lineSpacingExtra = 0f
            if (base.lineHeight > 0) {
                val lineHeightPx = base.lineHeight * density
                val fontHeight = textPaint.getFontMetricsInt(null).toFloat()
                if (lineHeightPx > fontHeight) {
                    lineSpacingExtra = lineHeightPx - fontHeight
                }
            }

            val layout = StaticLayout.Builder
                .obtain(spannable, 0, spannable.length, textPaint, widthPx)
                .setLineSpacing(lineSpacingExtra, 1f)
                .setIncludePad(true) // matches TextView default
                .build()

            val measuredHeight = layout.height.toFloat() / density
            return floatArrayOf(width, measuredHeight)
        }
    }
}
