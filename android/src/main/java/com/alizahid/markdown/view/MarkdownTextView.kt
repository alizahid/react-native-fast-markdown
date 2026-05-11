package com.alizahid.markdown.view

import android.content.Context
import androidx.appcompat.widget.AppCompatTextView
import com.alizahid.markdown.renderer.spans.LinkTouchMovementMethod

/**
 * Text view used to display block-level markdown text segments. Mirrors
 * iOS MarkdownInternalTextView: emits a layout-changed callback on
 * onSizeChanged so overlay views (spoiler, mention) can rebuild their
 * per-line rect geometry.
 *
 * Phase 2: only renders text. Overlays are added in Phase 5.
 */
class MarkdownTextView @JvmOverloads constructor(
  context: Context,
  attrs: android.util.AttributeSet? = null,
  defStyle: Int = 0,
) : AppCompatTextView(context, attrs, defStyle) {

  /** Invoked after every layout pass — overlays use this to recompute glyph rects. */
  var onLayoutChanged: (() -> Unit)? = null

  init {
    movementMethod = LinkTouchMovementMethod()
    includeFontPadding = false
    setTextIsSelectable(false)
    // Make the view focusable enough to receive touch but not steal
    // keyboard focus from RN gesture handlers.
    isFocusable = false
    isFocusableInTouchMode = false
  }

  override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
    super.onSizeChanged(w, h, oldw, oldh)
    onLayoutChanged?.invoke()
  }
}
