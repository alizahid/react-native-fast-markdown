package com.markdown.renderer.spans

import android.graphics.Paint

/**
 * A span applied to the gap newline between blocks. Sets the line
 * height to the gap value so the empty line acts as controlled
 * vertical spacing between paragraphs/headings/etc.
 */
class GapSpan(private val gapPx: Int) : android.text.style.LineHeightSpan {
    override fun chooseHeight(
        text: CharSequence,
        start: Int,
        end: Int,
        spanstartv: Int,
        lineHeight: Int,
        fm: Paint.FontMetricsInt,
    ) {
        // Force the line to be exactly gapPx tall
        fm.top = -gapPx
        fm.ascent = -gapPx
        fm.descent = 0
        fm.bottom = 0
    }
}
