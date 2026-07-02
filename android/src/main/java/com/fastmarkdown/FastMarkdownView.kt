package com.fastmarkdown

import android.content.Context
import android.graphics.Color
import android.view.ViewGroup
import com.fastmarkdown.render.ContentCache
import com.fastmarkdown.style.StyleConfig
import com.fastmarkdown.views.BlockTextView

/**
 * Host view: a vertical stack of block views. Fabric supplies the final
 * frame (the C++ shadow node measured the same cached content), so onLayout
 * only distributes block frames.
 */
class FastMarkdownView(context: Context) : ViewGroup(context) {
  private var markdown: String = ""
  private var stylesJson: String = ""

  fun setMarkdown(value: String?) {
    val next = value ?: ""
    if (next != markdown) {
      markdown = next
      requestLayout()
      invalidate()
    }
  }

  fun setStylesJson(value: String?) {
    val next = value ?: ""
    if (next != stylesJson) {
      stylesJson = next
      requestLayout()
      invalidate()
    }
  }

  override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
    // Fabric passes exact dimensions computed by the shadow node.
    setMeasuredDimension(
      MeasureSpec.getSize(widthMeasureSpec),
      MeasureSpec.getSize(heightMeasureSpec),
    )
  }

  override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
    val density = resources.displayMetrics.density
    // Pinned to 1.0 until allowFontScaling lands; must match the shadow node.
    val fontScale = 1.0f
    val styles = StyleConfig.from(stylesJson)

    setBackgroundColor(styles.backgroundColor ?: Color.TRANSPARENT)

    val paddingLeftPx = (styles.paddingLeft * density).toInt()
    val paddingRightPx = (styles.paddingRight * density).toInt()
    val contentWidthPx = (r - l) - paddingLeftPx - paddingRightPx
    if (contentWidthPx <= 0 || markdown.isEmpty()) {
      removeAllViews()
      return
    }

    val content = ContentCache.get(markdown, stylesJson, fontScale)
    val blockLayout = content.layoutFor(contentWidthPx)
    val layouts = blockLayout.layouts

    while (childCount > layouts.size) {
      removeViewAt(childCount - 1)
    }
    while (childCount < layouts.size) {
      addView(BlockTextView(context))
    }

    var y = (styles.paddingTop * density).toInt()
    val gapPx = (styles.gap * density).toInt()
    layouts.forEachIndexed { index, layout ->
      val child = getChildAt(index) as BlockTextView
      child.setTextLayout(layout)
      val height = layout.height
      child.measure(
        MeasureSpec.makeMeasureSpec(contentWidthPx, MeasureSpec.EXACTLY),
        MeasureSpec.makeMeasureSpec(height, MeasureSpec.EXACTLY),
      )
      child.layout(paddingLeftPx, y, paddingLeftPx + contentWidthPx, y + height)
      y += height
      if (index < layouts.size - 1) {
        y += gapPx
      }
    }
  }

  override fun shouldDelayChildPressedState(): Boolean = false
}
