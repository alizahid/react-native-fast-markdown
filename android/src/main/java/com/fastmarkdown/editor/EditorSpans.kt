package com.fastmarkdown.editor

import android.graphics.Typeface
import android.text.TextPaint
import android.text.style.MetricAffectingSpan

/** Inline mark bits; mirrors fastmarkdown::EditorMark in cpp/core/EditorRuns.h. */
object EditorMarks {
  const val BOLD = 1
  const val ITALIC = 1 shl 1
  const val STRIKETHROUGH = 1 shl 2
  const val INLINE_CODE = 1 shl 3
  const val SPOILER = 1 shl 4
  const val SUPERSCRIPT = 1 shl 5
  const val SUBSCRIPT = 1 shl 6

  val ALL = intArrayOf(
    BOLD, ITALIC, STRIKETHROUGH, INLINE_CODE, SPOILER, SUPERSCRIPT, SUBSCRIPT,
  )
}

/**
 * Data-only source of truth for one inline mark over a range. Visual styling
 * is carried by [EditorDisplaySpan]s rebuilt from these after every change.
 */
class EditorMarkSpan(val mark: Int)

/** Derived visual styling for the combined mark flags of a range. */
class EditorDisplaySpan(private val flags: Int) : MetricAffectingSpan() {
  override fun updateMeasureState(paint: TextPaint) {
    apply(paint)
  }

  override fun updateDrawState(paint: TextPaint) {
    apply(paint)
    if (flags and EditorMarks.STRIKETHROUGH != 0) {
      paint.isStrikeThruText = true
    }
    if (flags and EditorMarks.INLINE_CODE != 0) {
      paint.bgColor = 0x26808080
    }
    if (flags and EditorMarks.SPOILER != 0) {
      paint.bgColor = 0x40595959
    }
  }

  private fun apply(paint: TextPaint) {
    var style = paint.typeface?.style ?: Typeface.NORMAL
    if (flags and EditorMarks.BOLD != 0) {
      style = style or Typeface.BOLD
    }
    if (flags and EditorMarks.ITALIC != 0) {
      style = style or Typeface.ITALIC
    }
    val base =
      if (flags and EditorMarks.INLINE_CODE != 0) Typeface.MONOSPACE else paint.typeface
    paint.typeface = Typeface.create(base, style)

    // Sup/sub match the viewer's 0.7 scaling.
    if (flags and (EditorMarks.SUPERSCRIPT or EditorMarks.SUBSCRIPT) != 0) {
      val size = paint.textSize
      paint.textSize = size * 0.7f
      if (flags and EditorMarks.SUPERSCRIPT != 0) {
        paint.baselineShift -= (size * 0.33f).toInt()
      } else {
        paint.baselineShift += (size * 0.15f).toInt()
      }
    }
  }
}
