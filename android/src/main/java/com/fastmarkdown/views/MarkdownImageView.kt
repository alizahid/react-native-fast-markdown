package com.fastmarkdown.views

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Rect
import android.graphics.RectF
import android.view.View
import com.fastmarkdown.image.ImageLoader
import com.fastmarkdown.render.Block

/**
 * One markdown image: rounded-corner aspect-fit bitmap, background while
 * loading. Requests are URL-owned; this view only listens.
 */
class MarkdownImageView(context: Context) : View(context) {
  private var block: Block.Image? = null
  private var bitmap: Bitmap? = null
  private val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
  private val clipPath = Path()

  /** Fires once with the intrinsic dp size when the bitmap arrives. */
  var onIntrinsicSize: ((String, Float, Float) -> Unit)? = null

  fun bind(image: Block.Image) {
    block = image
    val cached = ImageLoader.cached(image.url)
    bitmap = cached
    if (cached != null) {
      // Report even for cache hits so a fresh view (JS reload, recycling)
      // still resizes un-presized images.
      reportIntrinsic(image.url, cached)
    } else {
      val boundUrl = image.url
      ImageLoader.load(context, boundUrl) { loaded ->
        if (block?.url != boundUrl) {
          return@load
        }
        bitmap = loaded
        invalidate()
        if (loaded != null) {
          reportIntrinsic(boundUrl, loaded)
        }
      }
    }
    invalidate()
  }

  private fun reportIntrinsic(url: String, loaded: android.graphics.Bitmap) {
    // Image pixels map 1:1 to dp (web semantics): a 600px image is 600dp
    // wide before clamping to the container.
    onIntrinsicSize?.invoke(url, loaded.width.toFloat(), loaded.height.toFloat())
  }

  override fun onDraw(canvas: Canvas) {
    val image = block ?: return
    val width = width.toFloat()
    val height = height.toFloat()

    if (image.borderRadiusPx > 0) {
      clipPath.reset()
      clipPath.addRoundRect(
        RectF(0f, 0f, width, height),
        image.borderRadiusPx,
        image.borderRadiusPx,
        Path.Direction.CW,
      )
      canvas.clipPath(clipPath)
    }

    paint.style = Paint.Style.FILL
    paint.color = image.backgroundColor ?: Color.TRANSPARENT
    canvas.drawRect(0f, 0f, width, height, paint)

    val loaded = bitmap ?: return
    // Aspect-fit inside the block frame.
    val scale = minOf(width / loaded.width, height / loaded.height)
    val drawW = loaded.width * scale
    val drawH = loaded.height * scale
    val left = (width - drawW) / 2f
    val top = (height - drawH) / 2f
    canvas.drawBitmap(
      loaded,
      Rect(0, 0, loaded.width, loaded.height),
      RectF(left, top, left + drawW, top + drawH),
      paint,
    )
  }
}
