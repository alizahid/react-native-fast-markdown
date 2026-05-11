package com.alizahid.markdown.renderer.spans

import android.os.Handler
import android.os.Looper
import android.text.Layout
import android.text.Spannable
import android.text.method.LinkMovementMethod
import android.view.MotionEvent
import android.view.ViewConfiguration
import android.widget.TextView
import kotlin.math.abs

/**
 * Movement method that distinguishes tap (onLinkPress) from long-press
 * (onLinkLongPress) on `LinkClickableSpan` ranges.
 *
 * Android has no equivalent of iOS's UITextItemInteractionPresentActions
 * "native preview popover" for http(s) URLs — so every long press fires
 * to JS via `onLinkLongPress`. Documented as a platform difference.
 */
class LinkTouchMovementMethod : LinkMovementMethod() {

  private val mainHandler = Handler(Looper.getMainLooper())
  private var pendingSpan: LinkClickableSpan? = null
  private var longPressFired: Boolean = false
  private var downX: Float = 0f
  private var downY: Float = 0f

  override fun onTouchEvent(widget: TextView, buffer: Spannable, event: MotionEvent): Boolean {
    val action = event.actionMasked
    when (action) {
      MotionEvent.ACTION_DOWN -> {
        longPressFired = false
        downX = event.x
        downY = event.y
        val span = spanAtTouch(widget, buffer, event)
        pendingSpan = span
        if (span != null) {
          mainHandler.postDelayed({
            val s = pendingSpan ?: return@postDelayed
            if (s.onLongClick(widget)) {
              longPressFired = true
              pendingSpan = null
            }
          }, ViewConfiguration.getLongPressTimeout().toLong())
          return true
        }
      }
      MotionEvent.ACTION_MOVE -> {
        val slop = ViewConfiguration.get(widget.context).scaledTouchSlop
        if (abs(event.x - downX) > slop || abs(event.y - downY) > slop) {
          cancelPending()
        }
      }
      MotionEvent.ACTION_UP -> {
        if (longPressFired) {
          longPressFired = false
          pendingSpan = null
          return true
        }
        val pending = pendingSpan
        cancelPending()
        if (pending != null) {
          pending.onClick(widget)
          return true
        }
      }
      MotionEvent.ACTION_CANCEL -> cancelPending()
    }
    return super.onTouchEvent(widget, buffer, event)
  }

  private fun cancelPending() {
    mainHandler.removeCallbacksAndMessages(null)
    pendingSpan = null
  }

  private fun spanAtTouch(widget: TextView, buffer: Spannable, event: MotionEvent): LinkClickableSpan? {
    val x = (event.x - widget.totalPaddingLeft + widget.scrollX).toInt()
    val y = (event.y - widget.totalPaddingTop + widget.scrollY).toInt()
    val layout: Layout = widget.layout ?: return null
    val line = layout.getLineForVertical(y)
    val offset = layout.getOffsetForHorizontal(line, x.toFloat())
    val spans = buffer.getSpans(offset, offset, LinkClickableSpan::class.java)
    return spans.firstOrNull()
  }
}
