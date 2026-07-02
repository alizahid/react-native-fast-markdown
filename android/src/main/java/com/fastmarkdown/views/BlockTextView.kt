package com.fastmarkdown.views

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.text.Spanned
import android.text.StaticLayout
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import com.fastmarkdown.render.Block
import com.fastmarkdown.render.spans.LinkSpan
import com.fastmarkdown.render.spans.SpoilerSpan
import kotlin.math.abs

/**
 * Draws one block's StaticLayout plus spoiler covers, and hit-tests links,
 * mentions, and spoilers by character range.
 */
class BlockTextView(context: Context) : View(context) {
  private var layout: StaticLayout? = null
  private var textBlock: Block.Text? = null
  var host: MarkdownHost? = null

  private val coverPaint = Paint(Paint.ANTI_ALIAS_FLAG)
  private val coverPath = Path()

  private var downX = 0f
  private var downY = 0f
  private var longPressFired = false
  private val longPressRunnable = Runnable {
    longPressFired = true
    pressedLink?.let { host?.onLinkLongPress(it.url) }
  }
  private var pressedLink: LinkSpan? = null
  private var pressedSpoiler: SpoilerSpan? = null

  fun setTextLayout(value: StaticLayout) {
    if (layout !== value) {
      layout = value
      contentDescription = value.text
      importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_YES
      requestLayout()
      invalidate()
    }
  }

  fun setBlock(block: Block.Text) {
    textBlock = block
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
    val text = layout ?: return
    text.draw(canvas)
    drawSpoilerCovers(canvas, text)
  }

  // One contiguous rounded polygon per spoiler (union of per-line run
  // rects), drawn over the text until revealed.
  private fun drawSpoilerCovers(canvas: Canvas, text: StaticLayout) {
    val spanned = text.text as? Spanned ?: return
    val block = textBlock ?: return
    val hostRef = host ?: return
    val spans = spanned.getSpans(0, spanned.length, SpoilerSpan::class.java)
    if (spans.isEmpty()) {
      return
    }

    coverPaint.style = Paint.Style.FILL
    coverPaint.color = block.spoilerColor

    for (span in spans) {
      if (hostRef.isSpoilerRevealed(span.id)) {
        continue
      }
      val start = spanned.getSpanStart(span)
      val end = spanned.getSpanEnd(span)
      coverPath.reset()
      val firstLine = text.getLineForOffset(start)
      val lastLine = text.getLineForOffset(end)
      for (line in firstLine..lastLine) {
        val lineStart = maxOf(start, text.getLineStart(line))
        val lineEnd = minOf(end, text.getLineEnd(line))
        if (lineStart >= lineEnd) {
          continue
        }
        val left = text.getPrimaryHorizontal(lineStart)
        val right = text.getPrimaryHorizontal(lineEnd)
        coverPath.addRoundRect(
          RectF(
            minOf(left, right) - 2f,
            text.getLineTop(line).toFloat(),
            maxOf(left, right) + 2f,
            text.getLineBottom(line).toFloat(),
          ),
          block.spoilerRadiusPx,
          block.spoilerRadiusPx,
          Path.Direction.CW,
        )
      }
      canvas.drawPath(coverPath, coverPaint)
    }
  }

  override fun onTouchEvent(event: MotionEvent): Boolean {
    val text = layout ?: return false
    val spanned = text.text as? Spanned ?: return false

    when (event.actionMasked) {
      MotionEvent.ACTION_DOWN -> {
        val offset = offsetAt(text, event.x, event.y) ?: return false
        pressedLink = spanned.getSpans(offset, offset, LinkSpan::class.java).firstOrNull()
        pressedSpoiler = spanned.getSpans(offset, offset, SpoilerSpan::class.java).firstOrNull()
        if (pressedLink == null && pressedSpoiler == null) {
          return false
        }
        downX = event.x
        downY = event.y
        longPressFired = false
        if (pressedLink != null) {
          postDelayed(longPressRunnable, ViewConfiguration.getLongPressTimeout().toLong())
        }
        return true
      }
      MotionEvent.ACTION_MOVE -> {
        val slop = ViewConfiguration.get(context).scaledTouchSlop
        if (abs(event.x - downX) > slop || abs(event.y - downY) > slop) {
          cancelPress()
        }
        return pressedLink != null || pressedSpoiler != null
      }
      MotionEvent.ACTION_UP -> {
        removeCallbacks(longPressRunnable)
        if (!longPressFired) {
          val spoiler = pressedSpoiler
          val link = pressedLink
          val hostRef = host
          if (spoiler != null && hostRef?.isSpoilerRevealed(spoiler.id) == false) {
            // First tap reveals; links inside come alive afterwards.
            hostRef.toggleSpoiler(spoiler.id)
          } else if (link != null) {
            hostRef?.onLinkPress(link.url)
          } else if (spoiler != null) {
            hostRef?.toggleSpoiler(spoiler.id)
          }
        }
        cancelPress()
        return true
      }
      MotionEvent.ACTION_CANCEL -> {
        cancelPress()
        return false
      }
    }
    return false
  }

  private fun cancelPress() {
    removeCallbacks(longPressRunnable)
    pressedLink = null
    pressedSpoiler = null
  }

  private fun offsetAt(text: StaticLayout, x: Float, y: Float): Int? {
    if (y < 0 || y > text.height) {
      return null
    }
    val line = text.getLineForVertical(y.toInt())
    if (x < text.getLineLeft(line) - 8 || x > text.getLineRight(line) + 8) {
      return null
    }
    return text.getOffsetForHorizontal(line, x)
  }
}
