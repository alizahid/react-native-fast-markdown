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
import kotlin.math.min
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
        // Match iOS `[UIColor colorWithWhite:0.0 alpha:0.18]`.
        pressOverlay.color = Color.argb(46, 0, 0, 0)
        return true
      }
      MotionEvent.ACTION_UP -> {
        pressOverlay.color = Color.TRANSPARENT
        val s = bestKnownNaturalSize()
        onPress?.invoke(url, s.width, s.height)
        return true
      }
      MotionEvent.ACTION_CANCEL, MotionEvent.ACTION_OUTSIDE -> {
        pressOverlay.color = Color.TRANSPARENT
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
   * Applies objectFit math. Bit-for-bit port of iOS
   * `+ [MarkdownImageView blockSizeForNaturalSize:...]`:
   *
   * - Default `cover` (when objectFit is anything but "contain") +
   *   BOTH maxWidth and maxHeight set → reserved rect is exactly
   *   (maxW, maxH) and the image fills via CENTER_CROP.
   * - Otherwise (contain, OR cover with only one max set) → use the
   *   image's natural size scaled down to fit whichever max
   *   constraint(s) are present (preserve aspect ratio).
   * - In every case, finally clamp to `availableWidth` (a hard
   *   layout constraint, not a style preference), preserving
   *   whatever aspect ratio resulted.
   */
  private fun blockSizeForNaturalSize(natural: Size, availableWidth: Int): Size {
    if (natural.width <= 0 || natural.height <= 0) {
      val w = if (fallbackWidth > 0) fallbackWidth else availableWidth
      return Size(w.coerceAtLeast(1), fallbackHeight.coerceAtLeast(1))
    }

    val cover = objectFit != "contain"
    var w: Float
    var h: Float
    if (cover && maxWidth > 0 && maxHeight > 0) {
      w = maxWidth.toFloat()
      h = maxHeight.toFloat()
    } else {
      w = natural.width.toFloat()
      h = natural.height.toFloat()
      var scale = 1f
      if (maxWidth > 0 && w > maxWidth) scale = min(scale, maxWidth / w)
      if (maxHeight > 0 && h > maxHeight) scale = min(scale, maxHeight / h)
      w *= scale
      h *= scale
    }

    if (availableWidth > 0 && w > availableWidth) {
      val s = availableWidth / w
      w *= s
      h *= s
    }

    return Size(kotlin.math.ceil(w).toInt().coerceAtLeast(1),
                kotlin.math.ceil(h).toInt().coerceAtLeast(1))
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
