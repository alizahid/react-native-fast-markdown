package com.alizahid.markdown.view

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.Drawable
import android.util.Size
import android.view.MotionEvent
import android.view.ViewConfiguration
import android.widget.FrameLayout
import android.widget.ImageView
import androidx.appcompat.widget.AppCompatImageView
import com.alizahid.markdown.style.ElementStyle
import com.bumptech.glide.Glide
import com.bumptech.glide.load.DataSource
import com.bumptech.glide.load.engine.GlideException
import com.bumptech.glide.request.RequestListener
import com.bumptech.glide.request.target.Target
import kotlin.math.abs
import kotlin.math.min

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
  private val pressOverlay = ColorDrawable(Color.TRANSPARENT)
  private var loadGeneration: Int = 0
  // iOS treats UIImage.size as POINTS; on a 3x device a 480-px-wide GIF
  // visually displays at 480pt. Glide hands us raw pixels — multiply by
  // density so the natural size we publish to the cache is in the same
  // raw-pixel domain the rest of the pipeline uses (style values were
  // already dp-scaled by StyleDeserializer).
  private val density: Float = context.resources.displayMetrics.density

  // Touch tracking — we don't pre-emptively block ancestor intercepts
  // on DOWN (that was making it impossible to scroll a ScrollView whose
  // finger started on an image). Instead we wait until UP: if the touch
  // moved past slop, the ScrollView has already won; if not, we fire
  // onPress.
  private val touchSlop: Int = ViewConfiguration.get(context).scaledTouchSlop
  private var downX: Float = 0f
  private var downY: Float = 0f

  init {
    addView(imageView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
    foreground = pressOverlay
    isClickable = true
  }

  override fun onAttachedToWindow() {
    super.onAttachedToWindow()
    // Defer Glide.with(view) until we're actually attached — calling it
    // earlier in init {} can no-op on Fabric because the view's window
    // isn't wired up yet, and the request manager gets bound to a
    // lifecycle that never resumes.
    loadImage()
  }

  override fun onDetachedFromWindow() {
    Glide.with(context.applicationContext).clear(imageView)
    super.onDetachedFromWindow()
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
        invalidate()
        downX = event.x
        downY = event.y
        return true
      }
      MotionEvent.ACTION_MOVE -> {
        if (abs(event.x - downX) > touchSlop || abs(event.y - downY) > touchSlop) {
          // The user is scrolling, not tapping. Drop the press tint so
          // we don't leave a stale highlight, and let the ScrollView
          // ancestor take the gesture by NOT consuming further events.
          if (pressOverlay.color != Color.TRANSPARENT) {
            pressOverlay.color = Color.TRANSPARENT
            invalidate()
          }
          return false
        }
      }
      MotionEvent.ACTION_UP -> {
        val wasPressed = pressOverlay.color != Color.TRANSPARENT
        pressOverlay.color = Color.TRANSPARENT
        invalidate()
        if (wasPressed && abs(event.x - downX) <= touchSlop &&
          abs(event.y - downY) <= touchSlop
        ) {
          val s = bestKnownNaturalSize()
          onPress?.invoke(url, s.width, s.height)
        }
        return true
      }
      MotionEvent.ACTION_CANCEL, MotionEvent.ACTION_OUTSIDE -> {
        pressOverlay.color = Color.TRANSPARENT
        invalidate()
        return true
      }
    }
    return super.onTouchEvent(event)
  }

  private fun loadImage() {
    if (url.isEmpty()) return
    val currentGen = ++loadGeneration
    // Application context: Glide.with(View) walks up the parent chain
    // looking for an Activity / Fragment, and in Fabric our view may
    // not have one — falling back to the application context is the
    // same path Glide takes internally when no host is found, but
    // avoids a NPE inside Glide.with(view) when the lookup fails.
    Glide.with(context.applicationContext)
      .load(url)
      .listener(object : RequestListener<Drawable> {
        override fun onLoadFailed(
          e: GlideException?, model: Any?,
          target: Target<Drawable>, isFirstResource: Boolean,
        ): Boolean {
          android.util.Log.w("MarkdownImageView", "Glide load failed for $url", e)
          return false
        }

        override fun onResourceReady(
          resource: Drawable, model: Any,
          target: Target<Drawable>?, dataSource: DataSource, isFirstResource: Boolean,
        ): Boolean {
          if (currentGen != loadGeneration) return false // stale
          val rawW = resource.intrinsicWidth
          val rawH = resource.intrinsicHeight
          if (rawW > 0 && rawH > 0) {
            // Scale Glide's raw-pixel intrinsic into the dp-scaled
            // raw-pixel domain we share with style values + iOS points.
            val w = (rawW * density).toInt()
            val h = (rawH * density).toInt()
            MarkdownImageSizeCache.put(url, Size(w, h))
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
    // fallbackHeight is the iOS kDefaultImageHeight default scaled to
    // raw pixels by the caller (MarkdownView.buildImageSegment).
    val w = if (fallbackWidth > 0) fallbackWidth else if (maxWidth > 0) maxWidth else 0
    val h = if (fallbackHeight > 0) fallbackHeight else (200f * density).toInt()
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
