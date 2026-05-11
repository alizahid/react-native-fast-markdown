package com.alizahid.markdown.view

import android.animation.ObjectAnimator
import android.content.Context
import android.graphics.Color
import android.graphics.Path
import android.graphics.RectF
import android.text.Layout
import android.text.Spanned
import com.alizahid.markdown.renderer.spans.SpoilerMarkerSpan

/**
 * Cover overlay painted on top of a MarkdownTextView. Reads
 * SpoilerMarkerSpan ranges off the text view's Spanned, queries the
 * Layout for per-line glyph rects, builds a staircase Path via
 * MarkdownPressableOverlay.shapePathForRects, and lets the user reveal
 * a spoiler by tapping it. Mirrors ios/views/MarkdownSpoilerOverlay.
 *
 * Reveal-state is keyed by SpoilerMarkerSpan.id (a stable hash) so
 * scrolling away and back preserves what's been revealed.
 */
class MarkdownSpoilerOverlay(
  context: Context,
  private val host: MarkdownTextView,
  fillColor: Int,
  cornerRadius: Float,
) : MarkdownPressableOverlay(context) {

  data class SpoilerHit(val span: SpoilerMarkerSpan, val path: Path, val bounds: RectF)

  private val cornerRadiusPx: Float = cornerRadius
  private val hits = mutableListOf<SpoilerHit>()
  private val revealedIds = mutableSetOf<String>()

  init {
    setColors(fillColor, pressedColorFor(fillColor))
  }

  /** Recomputes shapes — call after the host's Layout settles. */
  fun update() {
    val layout: Layout = host.layout ?: return
    val text = host.text as? Spanned ?: return
    val spans = text.getSpans(0, text.length, SpoilerMarkerSpan::class.java)
    hits.clear()
    if (spans.isEmpty()) {
      setShapePath(null)
      invalidate()
      return
    }

    val combined = Path()
    for (span in spans) {
      if (revealedIds.contains(span.id)) continue
      val s = text.getSpanStart(span)
      val e = text.getSpanEnd(span)
      if (s < 0 || e <= s) continue
      val rects = lineRects(layout, s, e, span.isBlock)
      if (rects.isEmpty()) continue
      val p = shapePathForRects(rects, cornerRadiusPx)
      val bounds = RectF().also { p.computeBounds(it, true) }
      hits.add(SpoilerHit(span, p, bounds))
      combined.addPath(p)
    }
    setShapePath(combined)
    invalidate()
  }

  override fun onTap(x: Float, y: Float) {
    val hit = hits.firstOrNull { it.path.let { p -> p.contains(x, y) } } ?: hitByBounds(x, y)
    if (hit != null) {
      revealedIds.add(hit.span.id)
      animateRevealFor(hit)
    }
  }

  private fun hitByBounds(x: Float, y: Float): SpoilerHit? =
    hits.firstOrNull { it.bounds.contains(x, y) }

  private fun animateRevealFor(hit: SpoilerHit) {
    // Approximation: fade the whole overlay's alpha 1 → 0 and rebuild
    // afterwards. iOS animates only the revealed sub-path; this is
    // visually equivalent when there's a single open spoiler at a time.
    val anim = ObjectAnimator.ofFloat(this, "alpha", 1f, 0f)
    anim.duration = 250
    anim.addListener(object : android.animation.AnimatorListenerAdapter() {
      override fun onAnimationEnd(animation: android.animation.Animator) {
        alpha = 1f
        update()
      }
    })
    anim.start()
  }

  private fun lineRects(layout: Layout, start: Int, end: Int, isBlock: Boolean): List<RectF> {
    val firstLine = layout.getLineForOffset(start)
    val lastLine = layout.getLineForOffset(end)
    val rects = mutableListOf<RectF>()
    for (line in firstLine..lastLine) {
      val lineStart = layout.getLineStart(line)
      val lineEnd = layout.getLineEnd(line)
      val s = maxOf(start, lineStart)
      val e = minOf(end, lineEnd)
      if (e <= s) continue
      val x1 = layout.getPrimaryHorizontal(s)
      val x2 = if (e == lineEnd && line < lastLine) layout.getLineRight(line) else layout.getPrimaryHorizontal(e)
      val top = layout.getLineTop(line).toFloat()
      val bottom = layout.getLineBottom(line).toFloat()
      rects.add(RectF(minOf(x1, x2), top, maxOf(x1, x2), bottom))
    }
    if (isBlock && rects.size > 1) {
      val u = RectF(rects[0])
      for (r in rects) u.union(r)
      return listOf(u)
    }
    // Pull adjacent line rects together vertically so the staircase
    // outline is continuous (no gap between lines).
    for (i in 0 until rects.size - 1) {
      val midY = (rects[i].bottom + rects[i + 1].top) / 2f
      rects[i].bottom = midY
      rects[i + 1].top = midY
    }
    return rects
  }
}
