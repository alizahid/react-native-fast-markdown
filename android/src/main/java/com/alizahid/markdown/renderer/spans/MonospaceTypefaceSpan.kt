package com.alizahid.markdown.renderer.spans

import android.graphics.Paint
import android.graphics.Typeface
import android.text.TextPaint
import android.text.style.MetricAffectingSpan

/** Forces Typeface.MONOSPACE for the spanned range, preserving weight/italic. */
class MonospaceTypefaceSpan : MetricAffectingSpan() {
  override fun updateDrawState(ds: TextPaint) = apply(ds)
  override fun updateMeasureState(p: TextPaint) = apply(p)
  private fun apply(p: Paint) {
    val current = p.typeface
    val style = current?.style ?: Typeface.NORMAL
    p.typeface = Typeface.create(Typeface.MONOSPACE, style)
  }
}
