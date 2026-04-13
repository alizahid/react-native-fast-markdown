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

    // Shared TextPaint — StaticLayout is thread-safe for measurement.
    // We sync on this to avoid concurrent mutation of the paint.
    private val textPaint = TextPaint().apply {
        isAntiAlias = true
    }

    /**
     * Measure markdown content. Returns [width, height] as floats.
     * Called from JNI (MarkdownMeasurerJNI.cpp).
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

        // We need a Context-free renderer for shadow-thread measurement.
        // MarkdownRenderer takes Context only for density — we pass it
        // explicitly here via the TextPaint.
        val renderer = MarkdownRenderer.createForMeasurement(density)
        val spannable = renderer.render(ast, styleConfig, effectiveTags.toSet())

        val widthPx = (width * density).toInt().coerceAtLeast(1)

        synchronized(textPaint) {
            val base = styleConfig.base
            textPaint.textSize = base.resolvedFontSize() * density
            textPaint.typeface = base.resolveTypeface()

            val layout = StaticLayout.Builder
                .obtain(spannable, 0, spannable.length, textPaint, widthPx)
                .build()

            val measuredHeight = layout.height.toFloat() / density
            return floatArrayOf(width, measuredHeight)
        }
    }
}
