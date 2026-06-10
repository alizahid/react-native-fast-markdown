package com.alizahid.markdown.renderer

import android.text.Layout
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.TextPaint
import android.text.style.AlignmentSpan
import android.text.style.StrikethroughSpan
import android.text.style.UnderlineSpan
import com.alizahid.markdown.renderer.spans.LineHeightSpan

/**
 * Paragraph-level span application (lineHeight, textAlign). Character
 * styling goes through RenderContext.applyAttributes on leaf runs;
 * mirrors iOS where character attrs live in the attribute dictionary
 * and paragraph style is computed per block by
 * `applyParagraphPropertiesFromStyle:`.
 */
object StyleAttributes {

  fun applyParagraphProperties(
    lineHeightPx: Float,
    textAlign: String?,
    into: SpannableStringBuilder,
    start: Int,
    end: Int,
  ) {
    if (start >= end) return
    val flags = Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
    if (!lineHeightPx.isNaN() && lineHeightPx > 0f) {
      into.setSpan(LineHeightSpan(lineHeightPx.toInt()), start, end, flags)
    }
    textAlign?.let {
      val align = when (it) {
        "center" -> Layout.Alignment.ALIGN_CENTER
        "right" -> Layout.Alignment.ALIGN_OPPOSITE
        // Android has no per-span justification (TextView-level
        // JUSTIFICATION_MODE_INTER_WORD only, API 26+); fall back left.
        else -> Layout.Alignment.ALIGN_NORMAL
      }
      into.setSpan(AlignmentSpan.Standard(align), start, end, flags)
    }
  }
}

/** Underline whose line color can differ from the text color (API 29+;
 *  earlier versions fall back to the text color). */
internal class ColoredUnderlineSpan(private val color: Int) : UnderlineSpan() {
  override fun updateDrawState(ds: TextPaint) {
    super.updateDrawState(ds)
    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
      ds.underlineColor = color
    }
  }
}

/** Strikethrough honoring textDecorationColor. Android's strike line
 *  always uses the paint color, so the text color is swapped at draw
 *  time — matching how iOS colors the strike via
 *  NSStrikethroughColorAttributeName (visually the strike + text share
 *  the configured color when the caller sets only the decoration
 *  color, which is also iOS's strikethrough renderer fallback). */
internal class ColoredStrikethroughSpan(private val color: Int) : StrikethroughSpan() {
  override fun updateDrawState(ds: TextPaint) {
    super.updateDrawState(ds)
    ds.color = color
  }
}
