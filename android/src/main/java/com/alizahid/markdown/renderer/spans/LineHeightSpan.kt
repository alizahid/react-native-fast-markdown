package com.alizahid.markdown.renderer.spans

import android.graphics.Paint
import android.text.style.LineHeightSpan as PlatformLineHeightSpan

/**
 * Forces an exact line height (in pixels) across the spanned range,
 * mirroring iOS `NSParagraphStyle.minimumLineHeight = maximumLineHeight`.
 */
class LineHeightSpan(private val heightPx: Int) : PlatformLineHeightSpan {
  override fun chooseHeight(
    text: CharSequence,
    start: Int,
    end: Int,
    spanstartv: Int,
    lineHeight: Int,
    fm: Paint.FontMetricsInt,
  ) {
    val originalHeight = fm.descent - fm.ascent
    val target = heightPx.coerceAtLeast(originalHeight)
    val extra = target - originalHeight
    val below = extra / 2
    val above = extra - below
    fm.ascent -= above
    fm.top -= above
    fm.descent += below
    fm.bottom += below
  }
}
