package com.fastmarkdown

import android.content.Context
import android.graphics.Color
import android.view.ViewGroup
import com.fastmarkdown.render.ContentCache
import com.fastmarkdown.style.StyleConfig
import com.fastmarkdown.views.BlockStackView

/**
 * Host view: one nested block stack. Fabric supplies the final frame (the
 * C++ shadow node measured the same cached content), so onLayout only
 * distributes frames.
 */
class FastMarkdownView(context: Context) : ViewGroup(context) {
  private var markdown: String = ""
  private var stylesJson: String = ""
  private var boundKey: Pair<String, String>? = null
  private var boundWidth: Int = 0
  private val stack = BlockStackView(context)

  init {
    addView(stack)
  }

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
    val paddingTopPx = (styles.paddingTop * density).toInt()
    val contentWidthPx = (r - l) - paddingLeftPx - paddingRightPx
    if (contentWidthPx <= 0 || markdown.isEmpty()) {
      stack.setBlocks(emptyList(), 0f)
      boundKey = null
      return
    }

    val content = ContentCache.get(markdown, stylesJson, fontScale)
    val layout = content.layoutFor(contentWidthPx)

    val key = markdown to stylesJson
    if (boundKey != key || boundWidth != contentWidthPx) {
      boundKey = key
      boundWidth = contentWidthPx
      stack.setBlocks(layout.measured, content.gap)
    }

    val contentHeight =
      (layout.totalHeightPx - (styles.paddingTop + styles.paddingBottom) * density).toInt()
    stack.measure(
      MeasureSpec.makeMeasureSpec(contentWidthPx, MeasureSpec.EXACTLY),
      MeasureSpec.makeMeasureSpec(contentHeight, MeasureSpec.EXACTLY),
    )
    stack.layout(
      paddingLeftPx,
      paddingTopPx,
      paddingLeftPx + contentWidthPx,
      paddingTopPx + contentHeight,
    )
  }

  override fun shouldDelayChildPressedState(): Boolean = false
}
