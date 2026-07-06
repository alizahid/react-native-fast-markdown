package com.fastmarkdown.views

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PointF
import android.graphics.RectF
import android.text.Spanned
import android.text.StaticLayout
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import com.fastmarkdown.render.Block
import com.fastmarkdown.render.spans.ChipSpan
import com.fastmarkdown.render.spans.LinkSpan
import com.fastmarkdown.render.spans.SpoilerSpan
import kotlin.math.abs
import kotlin.math.hypot

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
  private val chipPaint = Paint(Paint.ANTI_ALIAS_FLAG)
  private val chipPath = Path()

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
    drawChips(canvas, text)
    text.draw(canvas)
    drawSpoilerCovers(canvas, text)
  }

  // Rounded run backgrounds (inlineCode/link/mention chips and plain text
  // highlights), drawn UNDER the text. Vertical bounds come from the run's
  // real font metrics anchored on the drawn baseline, so ascenders and
  // descenders are always covered regardless of lineHeight.
  private fun drawChips(canvas: Canvas, text: StaticLayout) {
    val spanned = text.text as? Spanned ?: return
    val spans = spanned.getSpans(0, spanned.length, ChipSpan::class.java)
    if (spans.isEmpty()) {
      return
    }
    chipPaint.style = Paint.Style.FILL
    for (span in spans) {
      val start = spanned.getSpanStart(span)
      val end = spanned.getSpanEnd(span)
      if (start >= end) {
        continue
      }
      chipPaint.color = span.color
      val firstLine = text.getLineForOffset(start)
      val lastLine = text.getLineForOffset(end)
      val lineRects = ArrayList<RectF>(lastLine - firstLine + 1)
      for (line in firstLine..lastLine) {
        val lineStart = maxOf(start, text.getLineStart(line))
        val lineEnd = minOf(end, text.getLineEnd(line))
        if (lineStart >= lineEnd) {
          continue
        }
        val left = text.getPrimaryHorizontal(lineStart)
        val right = if (lineEnd < text.getLineEnd(line)) {
          text.getPrimaryHorizontal(lineEnd)
        } else {
          text.getLineRight(line)
        }
        val baseline = text.getLineBaseline(line).toFloat() + span.baselineShiftPx
        val padLeft = if (line == firstLine) span.padLeftPx else 0f
        val padRight = if (line == lastLine) span.padRightPx else 0f
        lineRects.add(
          RectF(
            (minOf(left, right) - padLeft).coerceAtLeast(0f),
            baseline + span.ascentPx - 1f,
            (maxOf(left, right) + padRight).coerceAtMost(width.toFloat()),
            baseline + span.descentPx + 1f,
          ),
        )
      }
      if (lineRects.isEmpty()) {
        continue
      }
      chipPath.reset()
      if (lineRects.size == 1) {
        chipPath.addRoundRect(lineRects[0], span.radiusPx, span.radiusPx, Path.Direction.CW)
      } else {
        buildRoundedOutline(lineRects, span.radiusPx, chipPath)
      }
      canvas.drawPath(chipPath, chipPaint)
    }
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
      val firstLine = text.getLineForOffset(start)
      val lastLine = text.getLineForOffset(end)
      val lineRects = ArrayList<RectF>(lastLine - firstLine + 1)
      for (line in firstLine..lastLine) {
        val lineStart = maxOf(start, text.getLineStart(line))
        val lineEnd = minOf(end, text.getLineEnd(line))
        if (lineStart >= lineEnd) {
          continue
        }
        val left = text.getPrimaryHorizontal(lineStart)
        // When the run continues past this line, primaryHorizontal(lineEnd)
        // resolves on the NEXT line; the run visually ends at the line's
        // right edge.
        val right = if (lineEnd < text.getLineEnd(line)) {
          text.getPrimaryHorizontal(lineEnd)
        } else {
          text.getLineRight(line)
        }
        lineRects.add(
          RectF(
            (minOf(left, right) - 2f).coerceAtLeast(0f),
            text.getLineTop(line).toFloat(),
            (maxOf(left, right) + 2f).coerceAtMost(width.toFloat()),
            text.getLineBottom(line).toFloat(),
          ),
        )
      }
      buildRoundedOutline(lineRects, block.spoilerRadiusPx, coverPath)
      canvas.drawPath(coverPath, coverPaint)
    }
  }

  // Union outline of vertically stacked per-line rects with every outline
  // corner (convex and concave) rounded, so a wrapped spoiler reads as one
  // contiguous shape instead of stacked pills. Consecutive lines merge only
  // when they horizontally overlap; a wrapped run whose first segment ends
  // right of where the next begins renders as separate shapes — one polygon
  // would self-intersect.
  private fun buildRoundedOutline(lines: List<RectF>, radius: Float, path: Path) {
    path.reset()
    var start = 0
    for (i in 1..lines.size) {
      val split = i == lines.size ||
        minOf(lines[i - 1].right, lines[i].right) -
        maxOf(lines[i - 1].left, lines[i].left) <= 0.5f
      if (split) {
        appendRoundedOutline(lines.subList(start, i), radius, path)
        start = i
      }
    }
  }

  private fun appendRoundedOutline(lines: List<RectF>, radius: Float, path: Path) {
    if (lines.isEmpty()) {
      return
    }
    val pts = ArrayList<PointF>(lines.size * 4)
    val first = lines.first()
    val last = lines.last()
    // Clockwise: top edge, down the right side with a jog at each width
    // change, bottom edge, back up the left side.
    pts.add(PointF(first.left, first.top))
    pts.add(PointF(first.right, first.top))
    for (i in 0 until lines.size - 1) {
      val cur = lines[i]
      val next = lines[i + 1]
      if (abs(next.right - cur.right) > 0.5f) {
        pts.add(PointF(cur.right, cur.bottom))
        pts.add(PointF(next.right, cur.bottom))
      }
    }
    pts.add(PointF(last.right, last.bottom))
    pts.add(PointF(last.left, last.bottom))
    for (i in lines.size - 1 downTo 1) {
      val cur = lines[i]
      val prev = lines[i - 1]
      if (abs(prev.left - cur.left) > 0.5f) {
        pts.add(PointF(cur.left, cur.top))
        pts.add(PointF(prev.left, cur.top))
      }
    }
    var started = false
    val n = pts.size
    for (i in 0 until n) {
      val prev = pts[(i + n - 1) % n]
      val v = pts[i]
      val next = pts[(i + 1) % n]
      val inLen = hypot(v.x - prev.x, v.y - prev.y)
      val outLen = hypot(next.x - v.x, next.y - v.y)
      if (inLen < 0.01f || outLen < 0.01f) {
        continue
      }
      val r = minOf(radius, inLen / 2f, outLen / 2f)
      val entryX = v.x - (v.x - prev.x) / inLen * r
      val entryY = v.y - (v.y - prev.y) / inLen * r
      val exitX = v.x + (next.x - v.x) / outLen * r
      val exitY = v.y + (next.y - v.y) / outLen * r
      if (!started) {
        path.moveTo(entryX, entryY)
        started = true
      } else {
        path.lineTo(entryX, entryY)
      }
      path.quadTo(v.x, v.y, exitX, exitY)
    }
    if (started) {
      path.close()
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
        // Tell ancestors (including gesture-handler roots, which honor this
        // as "a native view took over") that this press is ours, so a
        // wrapping Pressable does not also fire for link/spoiler taps.
        parent?.requestDisallowInterceptTouchEvent(true)
        return true
      }
      MotionEvent.ACTION_MOVE -> {
        val slop = ViewConfiguration.get(context).scaledTouchSlop
        if (abs(event.x - downX) > slop || abs(event.y - downY) > slop) {
          cancelPress()
          // The finger is dragging: hand the gesture back so scroll views
          // can intercept and pan.
          parent?.requestDisallowInterceptTouchEvent(false)
        }
        return pressedLink != null || pressedSpoiler != null
      }
      MotionEvent.ACTION_UP -> {
        parent?.requestDisallowInterceptTouchEvent(false)
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
        parent?.requestDisallowInterceptTouchEvent(false)
        cancelPress()
        return false
      }
    }
    return false
  }

  override fun onDetachedFromWindow() {
    super.onDetachedFromWindow()
    // A teardown mid-press would otherwise fire the runnable ~500ms later
    // against a recycled host.
    cancelPress()
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
