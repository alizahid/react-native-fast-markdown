package com.fastmarkdown.views

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.text.Spannable
import android.text.Spanned
import android.text.TextPaint
import android.text.StaticLayout
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import com.fastmarkdown.render.Block
import com.fastmarkdown.render.spans.ChipSpan
import com.fastmarkdown.render.spans.LinkSpan
import com.fastmarkdown.render.spans.SpoilerHidingSpan
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
    syncSpoilerHiding(text)
    drawChips(canvas, text)
    text.draw(canvas)
    drawSpoilerCovers(canvas, text)
  }

  // Unrevealed spoiler text draws fully transparent — the cover hugs the
  // glyph ink, so glyphs would leak around it if drawn. Color-only spans
  // apply at draw time without re-layout. Reconciles against the spannable
  // itself: content is cached and shared across recycled views, so span
  // bookkeeping must not live in view state.
  private fun syncSpoilerHiding(text: StaticLayout) {
    val spannable = text.text as? Spannable ?: return
    val hostRef = host ?: return
    val spoilers = spannable.getSpans(0, spannable.length, SpoilerSpan::class.java)
    val hiding = spannable.getSpans(0, spannable.length, SpoilerHidingSpan::class.java)
    if (spoilers.isEmpty() && hiding.isEmpty()) {
      return
    }
    val hidden = HashSet<Int>()
    for (span in hiding) {
      if (hostRef.isSpoilerRevealed(span.id)) {
        spannable.removeSpan(span)
      } else {
        hidden.add(span.id)
      }
    }
    for ((id, group) in spoilers.groupBy { it.id }) {
      if (hostRef.isSpoilerRevealed(id) || id in hidden) {
        continue
      }
      spannable.setSpan(
        SpoilerHidingSpan(id),
        group.minOf { spannable.getSpanStart(it) },
        group.maxOf { spannable.getSpanEnd(it) },
        Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
      )
    }
  }

  // Overlays hug the text. lineHeight moves line boxes around the text, so
  // any box derived from them inherits that skew; these rects anchor on the
  // baseline instead. Horizontal comes from the segment's glyph ink;
  // vertical is the FONT's ink envelope (cap height above the baseline,
  // descender depth below) so every run of a font renders the same height
  // whether or not its particular glyphs have capitals or descenders.
  private val inkPadPx: Float
    get() = 2f * resources.displayMetrics.density

  private val inkPaint = TextPaint(Paint.ANTI_ALIAS_FLAG)
  private val inkBounds = android.graphics.Rect()
  private val capBounds = android.graphics.Rect()

  /** Overlay rect for one line's segment of a run, padded. */
  private fun inkRect(
    text: StaticLayout,
    line: Int,
    segmentStart: Int,
    segmentEnd: Int,
    typeface: android.graphics.Typeface?,
    textSizePx: Float,
    padLeft: Float,
    padRight: Float,
  ): RectF? {
    val chars = text.text.subSequence(segmentStart, segmentEnd).toString()
    if (chars.isBlank()) {
      return null
    }
    inkPaint.typeface = typeface
    inkPaint.textSize = textSizePx
    inkPaint.getTextBounds(chars, 0, chars.length, inkBounds)
    if (inkBounds.isEmpty) {
      return null
    }
    inkPaint.getTextBounds("H", 0, 1, capBounds)
    val descent = inkPaint.fontMetrics.descent
    val penX = text.getPrimaryHorizontal(segmentStart)
    val right = if (segmentEnd < text.getLineEnd(line)) {
      text.getPrimaryHorizontal(segmentEnd)
    } else {
      text.getLineRight(line)
    }
    val baseline = text.getLineBaseline(line).toFloat()
    val left = minOf(penX, right)
    return RectF(
      (left + inkBounds.left - padLeft).coerceAtLeast(0f),
      (baseline - capBounds.height() - inkPadPx).coerceAtLeast(0f),
      (left + inkBounds.right + padRight).coerceAtMost(width.toFloat()),
      (baseline + descent + inkPadPx).coerceAtMost(height.toFloat()),
    )
  }

  // Run background chips (inlineCode/link/mention and plain highlights),
  // drawn UNDER the text. Chips inside an unrevealed spoiler don't draw —
  // they would peek around the cover.
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
      if (start >= end || isInsideHiddenSpoiler(spanned, start, end)) {
        continue
      }
      chipPaint.color = span.color
      val firstLine = text.getLineForOffset(start)
      val lastLine = text.getLineForOffset(end)
      for (line in firstLine..lastLine) {
        val segmentStart = maxOf(start, text.getLineStart(line))
        val segmentEnd = minOf(end, text.getLineEnd(line))
        if (segmentStart >= segmentEnd) {
          continue
        }
        val rect = inkRect(
          text = text,
          line = line,
          segmentStart = segmentStart,
          segmentEnd = segmentEnd,
          typeface = span.typeface,
          textSizePx = span.textSizePx,
          padLeft = if (line == firstLine && span.padLeftPx > 0f) span.padLeftPx else inkPadPx,
          padRight = if (line == lastLine && span.padRightPx > 0f) span.padRightPx else inkPadPx,
        ) ?: continue
        chipPath.reset()
        chipPath.addRoundRect(rect, span.radiusPx, span.radiusPx, Path.Direction.CW)
        canvas.drawPath(chipPath, chipPaint)
      }
    }
  }

  private fun isInsideHiddenSpoiler(spanned: Spanned, start: Int, end: Int): Boolean {
    val hostRef = host ?: return false
    return spanned.getSpans(start, end, SpoilerSpan::class.java)
      .any { !hostRef.isSpoilerRevealed(it.id) }
  }

  // Spoiler cover chips, drawn OVER the (transparent) text until revealed.
  // A spoiler with mixed inline styling carries one span per run (same id);
  // per line the group's segment ink rects union into one cover.
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

    for ((id, group) in spans.groupBy { it.id }) {
      if (hostRef.isSpoilerRevealed(id)) {
        continue
      }
      val start = group.minOf { spanned.getSpanStart(it) }
      val end = group.maxOf { spanned.getSpanEnd(it) }
      if (start >= end) {
        continue
      }
      val firstLine = text.getLineForOffset(start)
      val lastLine = text.getLineForOffset(end)
      for (line in firstLine..lastLine) {
        var union: RectF? = null
        for (span in group) {
          val spanStart = maxOf(spanned.getSpanStart(span), text.getLineStart(line))
          val spanEnd = minOf(spanned.getSpanEnd(span), text.getLineEnd(line))
          if (spanStart >= spanEnd) {
            continue
          }
          val rect = inkRect(
            text = text,
            line = line,
            segmentStart = spanStart,
            segmentEnd = spanEnd,
            typeface = span.typeface,
            textSizePx = span.textSizePx,
            padLeft = inkPadPx,
            padRight = inkPadPx,
          ) ?: continue
          union = union?.apply { union(rect) } ?: rect
        }
        val rect = union ?: continue
        coverPath.reset()
        coverPath.addRoundRect(rect, block.spoilerRadiusPx, block.spoilerRadiusPx, Path.Direction.CW)
        canvas.drawPath(coverPath, coverPaint)
      }
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
