package com.alizahid.markdown.view

import android.content.Context
import android.view.View
import android.view.ViewGroup

/**
 * Frame-based vertical stack — manually measures and lays out children
 * top-to-bottom with a configurable gap. Mirrors
 * ios/views/MarkdownSegmentStackView. Deliberately not a LinearLayout
 * so the height math here matches MarkdownMeasurer exactly.
 *
 * Each child's own MarginLayoutParams horizontal margins are respected;
 * vertical inter-segment spacing comes from `spacing` (the base style's
 * `gap`).
 */
class MarkdownSegmentStack(context: Context) : ViewGroup(context) {

  var spacing: Int = 0

  override fun generateDefaultLayoutParams(): LayoutParams =
    MarginLayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT)

  override fun generateLayoutParams(attrs: android.util.AttributeSet?): LayoutParams =
    MarginLayoutParams(context, attrs)

  override fun checkLayoutParams(p: LayoutParams?): Boolean = p is MarginLayoutParams

  override fun generateLayoutParams(p: LayoutParams?): LayoutParams =
    MarginLayoutParams(p ?: generateDefaultLayoutParams())

  override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
    val widthSize = MeasureSpec.getSize(widthMeasureSpec)
    val widthMode = MeasureSpec.getMode(widthMeasureSpec)
    val innerWidth = (widthSize - paddingLeft - paddingRight).coerceAtLeast(0)

    var totalHeight = paddingTop + paddingBottom
    var visibleCount = 0
    var maxChildWidth = 0

    for (i in 0 until childCount) {
      val child = getChildAt(i)
      if (child.visibility == View.GONE) continue
      val lp = child.layoutParams as MarginLayoutParams
      val cw = (innerWidth - lp.leftMargin - lp.rightMargin).coerceAtLeast(0)
      // Hugging-content blocks (image segments) measure with AT_MOST so
      // they shrink to their preferred natural width. Everything else
      // measures EXACTLY so blocks span the full row — matches iOS
      // SegmentWidth(availableWidth) behavior in MarkdownSegmentStackView.
      val hugging = child is MarkdownBlockView && child.huggingContent
      val cWidthSpec = MeasureSpec.makeMeasureSpec(
        cw, if (hugging) MeasureSpec.AT_MOST else MeasureSpec.EXACTLY,
      )
      val cHeightSpec = MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
      child.measure(cWidthSpec, cHeightSpec)
      totalHeight += child.measuredHeight + lp.topMargin + lp.bottomMargin
      maxChildWidth = maxOf(maxChildWidth, child.measuredWidth + lp.leftMargin + lp.rightMargin)
      visibleCount++
    }
    if (visibleCount > 1) totalHeight += spacing * (visibleCount - 1)

    val resolvedWidth = when (widthMode) {
      MeasureSpec.EXACTLY -> widthSize
      MeasureSpec.AT_MOST -> minOf(widthSize, maxChildWidth + paddingLeft + paddingRight)
      else -> maxChildWidth + paddingLeft + paddingRight
    }
    setMeasuredDimension(resolvedWidth, totalHeight)
  }

  override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
    var y = paddingTop
    val innerWidth = (r - l) - paddingLeft - paddingRight
    for (i in 0 until childCount) {
      val child = getChildAt(i)
      if (child.visibility == View.GONE) continue
      val lp = child.layoutParams as MarginLayoutParams
      val cw = child.measuredWidth
      val ch = child.measuredHeight
      val childLeft = paddingLeft + lp.leftMargin
      val maxLeft = paddingLeft + innerWidth - cw - lp.rightMargin
      val left = childLeft.coerceAtMost(maxLeft.coerceAtLeast(childLeft))
      val top = y + lp.topMargin
      child.layout(left, top, left + cw, top + ch)
      y += ch + lp.topMargin + lp.bottomMargin
      val isLast = (i == childCount - 1)
      if (!isLast) y += spacing
    }
  }
}
