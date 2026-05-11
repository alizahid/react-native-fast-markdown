package com.alizahid.markdown.renderer.spans

import android.graphics.Paint
import android.graphics.Typeface
import android.text.TextPaint
import android.text.style.MetricAffectingSpan

/**
 * Like the platform `TypefaceSpan(family)`, but accepts a fully-built
 * Typeface (so we can pass a typeface produced by TypefaceResolver with
 * fine-grained weight/style baked in).
 */
class CustomTypefaceSpan(private val typeface: Typeface) : MetricAffectingSpan() {
  override fun updateDrawState(ds: TextPaint) = apply(ds)
  override fun updateMeasureState(p: TextPaint) = apply(p)
  private fun apply(p: Paint) { p.typeface = typeface }
}
