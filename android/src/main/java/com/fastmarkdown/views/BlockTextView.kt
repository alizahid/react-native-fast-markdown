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
      invalidate()
    }
  }

  override fun onDraw(canvas: Canvas) {
    layout?.draw(canvas)
  }
}
