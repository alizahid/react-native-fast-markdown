package com.alizahid.markdown.view

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.Drawable
import android.util.Size
import android.view.MotionEvent
import android.widget.FrameLayout
import android.widget.ImageView
import androidx.appcompat.widget.AppCompatImageView
import com.alizahid.markdown.style.ElementStyle
import com.bumptech.glide.Glide
import com.bumptech.glide.load.DataSource
import com.bumptech.glide.load.engine.GlideException
import com.bumptech.glide.request.RequestListener
import com.bumptech.glide.request.target.Target

/**
 * Block-level image view. Loads via Glide (memory + disk caching + GIF
 * animation handled by GifDrawable for `image/gif` resources). Mirrors
 * ios/views/MarkdownImageView.
 *
 * Size resolution priority (matches iOS bestKnownNaturalSize):
 *   1. propSize     — caller-supplied from <Markdown images={...} />
 *   2. cache hit    — discovered by an earlier load with the same URL
 *   3. fallback     — image style's width × height (or 200 default)
 *
 * When Glide reports a new natural size we publish it to
 * MarkdownImageSizeCache so the host MarkdownView can remeasure.
 */
class MarkdownImageView(
  context: Context,
  val url: String,
  private val propSize: Size?,
  private val fallbackWidth: Int,
  private val fallbackHeight: Int,
  private val maxWidth: Int,
  private val maxHeight: Int,
  private val objectFit: String?,
) : FrameLayout(context) {

  /** Tap handler — receives the URL and best-known natural size. */
  var onPress: ((url: String, width: Int, height: Int) -> Unit)? = null

  private val imageView = AppCompatImageView(context).apply {
    scaleType = if (objectFit == "contain") ImageView.ScaleType.FIT_CENTER else ImageView.ScaleType.CENTER_CROP
  }
  private val pressOverlay = ColorDrawable(Color.argb(0, 0, 0, 0))
  private var loadGeneration: Int = 0

  init {
    addView(imageView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
    foreground = pressOverlay
    isClickable = true
    loadImage()
  }

  override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
    val availableWidth = MeasureSpec.getSize(widthMeasureSpec)
    val natural = bestKnownNaturalSize()
    val size = blockSizeForNaturalSize(natural, availableWidth)
    setMeasuredDimension(size.width, size.height)
    imageView.measure(
      MeasureSpec.makeMeasureSpec(size.width, MeasureSpec.EXACTLY),
      MeasureSpec.makeMeasureSpec(size.height, MeasureSpec.EXACTLY),
    )
  }

  override fun onTouchEvent(event: MotionEvent): Boolean {
    when (event.actionMasked) {
      MotionEvent.ACTION_DOWN -> {
        pressOverlay.color = Color.argb(64, 0, 0, 0)
        return true
      }
      MotionEvent.ACTION_UP -> {
        pressOverlay.color = Color.argb(0, 0, 0, 0)
        val s = bestKnownNaturalSize()
        onPress?.invoke(url, s.width, s.height)
        return true
      }
      MotionEvent.ACTION_CANCEL, MotionEvent.ACTION_OUTSIDE -> {
        pressOverlay.color = Color.argb(0, 0, 0, 0)
        return true
      }
    }
    return super.onTouchEvent(event)
  }

  private fun loadImage() {
    if (url.isEmpty()) return
    val currentGen = ++loadGeneration
    Glide.with(this)
      .load(url)
      .listener(object : RequestListener<Drawable> {
        override fun onLoadFailed(
          e: GlideException?, model: Any?,
          target: Target<Drawable>, isFirstResource: Boolean,
        ): Boolean = false

        override fun onResourceReady(
          resource: Drawable, model: Any,
          target: Target<Drawable>?, dataSource: DataSource, isFirstResource: Boolean,
        ): Boolean {
          if (currentGen != loadGeneration) return false // stale
          val w = resource.intrinsicWidth
          val h = resource.intrinsicHeight
          if (w > 0 && h > 0) {
            MarkdownImageSizeCache.put(url, Size(w, h))
            // Trigger our own remeasure so the new aspect ratio applies.
            requestLayout()
          }
          return false
        }
      })
      .into(imageView)
  }

  /**
   * Resolved natural size: prop > cache > fallback. Mirrors iOS
   * MarkdownImageView.bestKnownNaturalSize.
   */
  fun bestKnownNaturalSize(): Size {
    propSize?.let { if (it.width > 0 && it.height > 0) return it }
    MarkdownImageSizeCache.get(url)?.let { if (it.width > 0 && it.height > 0) return it }
    val w = if (fallbackWidth > 0) fallbackWidth else if (maxWidth > 0) maxWidth else 0
    val h = if (fallbackHeight > 0) fallbackHeight else 200
    return Size(w, h)
  }

  /**
   * Applies objectFit math: `cover` (default) sizes to (maxW, maxH)
   * exactly and crops; `contain` aspect-fits inside (maxW, maxH).
   * Mirrors iOS MarkdownImageView.blockSizeForNaturalSize.
   */
  private fun blockSizeForNaturalSize(natural: Size, availableWidth: Int): Size {
    val effMaxW = if (maxWidth > 0) maxWidth.coerceAtMost(availableWidth) else availableWidth
    val effMaxH = if (maxHeight > 0) maxHeight else Int.MAX_VALUE

    if (natural.width <= 0 || natural.height <= 0) {
      return Size(effMaxW, fallbackHeight.coerceAtMost(effMaxH).coerceAtLeast(1))
    }

    return when (objectFit) {
      "cover" -> {
        val w = effMaxW
        val h = if (effMaxH == Int.MAX_VALUE) {
          (natural.height.toLong() * w / natural.width).toInt()
        } else effMaxH
        Size(w.coerceAtLeast(1), h.coerceAtLeast(1))
      }
      else -> {
        // contain (default if unspecified — matches RN expected behavior
        // for missing objectFit on a block image)
        val ratio = natural.width.toFloat() / natural.height.toFloat()
        var w = effMaxW
        var h = (w / ratio).toInt()
        if (h > effMaxH) {
          h = effMaxH
          w = (h * ratio).toInt()
        }
        Size(w.coerceAtLeast(1), h.coerceAtLeast(1))
      }
    }
  }

  companion object {
    fun pickStyleSizes(style: ElementStyle): IntArray {
      val maxW = if (!style.maxWidth.isNaN() && style.maxWidth > 0) style.maxWidth.toInt() else 0
      val maxH = if (!style.maxHeight.isNaN() && style.maxHeight > 0) style.maxHeight.toInt() else 0
      val w = if (!style.width.isNaN() && style.width > 0) style.width.toInt() else 0
      val h = if (!style.height.isNaN() && style.height > 0) style.height.toInt() else 0
      return intArrayOf(w, h, maxW, maxH)
    }
  }
}
