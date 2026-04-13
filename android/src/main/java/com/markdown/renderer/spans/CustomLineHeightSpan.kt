package com.markdown.renderer.spans

import android.graphics.Paint

/**
 * Enforces a fixed line height in pixels. Distributes extra space
 * above and below the text, matching iOS NSParagraphStyle
 * minimumLineHeight / maximumLineHeight behavior.
 */
class CustomLineHeightSpan(private val heightPx: Int) : android.text.style.LineHeightSpan {
    override fun chooseHeight(
        text: CharSequence,
        start: Int,
        end: Int,
        spanstartv: Int,
        lineHeight: Int,
        fm: Paint.FontMetricsInt,
    ) {
        val currentHeight = fm.descent - fm.ascent
        if (heightPx > currentHeight) {
            val extra = heightPx - currentHeight
            // Distribute: more below baseline (matching iOS)
            fm.descent += extra / 2
            fm.ascent -= extra - extra / 2
        }
    }
}
