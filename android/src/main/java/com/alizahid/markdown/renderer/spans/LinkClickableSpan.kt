package com.alizahid.markdown.renderer.spans

import android.text.TextPaint
import android.text.style.ClickableSpan
import android.view.View

/**
 * Inline link tap target. Holds the URL + optional title, plus
 * separate click and long-click callbacks. Drawing customization
 * (color, underline) is left to the wrapping ElementStyle so the
 * default link colour matches what the user configured.
 */
class LinkClickableSpan(
  val url: String,
  val title: String,
  private val onPress: ((url: String, title: String) -> Unit)?,
  private val onLongPress: ((url: String, title: String) -> Unit)?,
) : ClickableSpan() {

  override fun onClick(widget: View) {
    onPress?.invoke(url, title)
  }

  fun onLongClick(widget: View): Boolean {
    val cb = onLongPress ?: return false
    cb.invoke(url, title)
    return true
  }

  /** Do nothing: text colour / underline comes from ElementStyle spans. */
  override fun updateDrawState(ds: TextPaint) {
    // Intentionally no-op to keep style cascade authoritative.
  }
}
