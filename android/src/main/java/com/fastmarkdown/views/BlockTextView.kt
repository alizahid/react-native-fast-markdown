package com.fastmarkdown.views

import android.content.Context
import android.graphics.Canvas
import android.text.StaticLayout
import android.view.View

/** Draws one block's StaticLayout; layout construction happens off-view. */
class BlockTextView(context: Context) : View(context) {
  private var layout: StaticLayout? = null

  fun setTextLayout(value: StaticLayout) {
    if (layout !== value) {
      layout = value
      requestLayout()
      invalidate()
    }
  }

  override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
    // HorizontalScrollView measures children UNSPECIFIED; report the text size.
    val text = layout
    if (text != null) {
      setMeasuredDimension(
        resolveSize(text.width, widthMeasureSpec),
        resolveSize(text.height, heightMeasureSpec),
      )
    } else {
      super.onMeasure(widthMeasureSpec, heightMeasureSpec)
    }
  }

  override fun onDraw(canvas: Canvas) {
    layout?.draw(canvas)
  }
}
