package com.fastmarkdown.render

import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import com.fastmarkdown.style.LayoutStyleSpec

/** One renderable block; blocks nest (quote children, list row content). */
sealed class Block {
  class Text(val text: CharSequence, val paint: TextPaint) : Block()

  /** Code renders unwrapped inside a horizontal scroller. */
  class Code(val text: CharSequence, val paint: TextPaint, val style: LayoutStyleSpec) : Block()

  class Quote(val children: List<Block>, val style: LayoutStyleSpec) : Block()

  class ListRow(val marker: CharSequence, val markerPaint: TextPaint, val content: List<Block>)

  class ListBlock(
    val rows: List<ListRow>,
    val marginLeftPx: Float,
    val markerWidthPx: Float,
    val markerMarginLeftPx: Float,
  ) : Block()

  class Divider(val color: Int, val thicknessPx: Float) : Block()

  class Image(
    val url: String,
    val backgroundColor: Int?,
    val borderRadiusPx: Float,
    val heightPx: Float,
    val maxHeightPx: Float,
    val placeholderPx: Float,
  ) : Block()
}

/** Layout results for one block at one width. */
class MeasuredBlock(
  val block: Block,
  val heightPx: Float,
  val textLayout: StaticLayout?,
  /** Code: unwrapped content width for the scroller. */
  val contentWidthPx: Float,
  val children: List<MeasuredBlock>,
  /** List rows: marker layouts parallel to children groups. */
  val markerLayouts: List<StaticLayout>,
  /** List rows: measured content per row. */
  val rowContents: List<List<MeasuredBlock>>,
)

/**
 * Parsed + rendered markdown, shared between the Fabric measurer (layout
 * thread) and the mounted view (main thread). Per-width results are cached.
 */
class RenderedContent(
  val blocks: List<Block>,
  private val gapPx: Float,
  private val topPaddingPx: Float,
  private val bottomPaddingPx: Float,
  private val density: Float,
) {
  class WidthLayout(val measured: List<MeasuredBlock>, val totalHeightPx: Float)

  private data class LayoutKey(val widthPx: Int, val sizesHash: Int)

  private val layoutCache = HashMap<LayoutKey, WidthLayout>()

  /** imageSizes: url -> intrinsic dp size, merged prop + discovered. */
  @Synchronized
  fun layoutFor(widthPx: Int, imageSizes: Map<String, FloatArray> = emptyMap()): WidthLayout {
    val key = LayoutKey(widthPx, imageSizesHash(imageSizes))
    layoutCache[key]?.let { return it }

    val measured = blocks.map { measure(it, widthPx.toFloat(), imageSizes) }
    var height = topPaddingPx + bottomPaddingPx
    measured.forEachIndexed { index, block ->
      height += block.heightPx
      if (index < measured.size - 1) {
        height += gapPx
      }
    }

    val result = WidthLayout(measured, height)
    if (layoutCache.size > 4) {
      layoutCache.clear()
    }
    layoutCache[key] = result
    return result
  }

  private fun imageSizesHash(sizes: Map<String, FloatArray>): Int {
    var hash = sizes.size
    for ((url, size) in sizes) {
      hash = hash * 31 + url.hashCode()
      hash = hash * 31 + size[0].toInt()
      hash = hash * 31 + size[1].toInt()
    }
    return hash
  }

  fun stackHeight(children: List<MeasuredBlock>): Float {
    var height = 0f
    children.forEachIndexed { index, child ->
      height += child.heightPx
      if (index < children.size - 1) {
        height += gapPx
      }
    }
    return height
  }

  val gap: Float get() = gapPx

  private fun measure(
    block: Block,
    widthPx: Float,
    imageSizes: Map<String, FloatArray>,
  ): MeasuredBlock {
    return when (block) {
      is Block.Text -> {
        val layout = staticLayout(block.text, block.paint, widthPx.toInt(), wrap = true)
        MeasuredBlock(block, layout.height.toFloat(), layout, widthPx, emptyList(), emptyList(), emptyList())
      }

      is Block.Code -> {
        val desired = Layout.getDesiredWidth(block.text, block.paint)
        val layout = staticLayout(block.text, block.paint, kotlin.math.ceil(desired.toDouble()).toInt(), wrap = false)
        val height = layout.height + block.style.paddingTop + block.style.paddingBottom
        MeasuredBlock(block, height, layout, desired, emptyList(), emptyList(), emptyList())
      }

      is Block.Quote -> {
        val innerWidth = widthPx - block.style.paddingLeft - block.style.paddingRight -
          block.style.borderLeftWidth - block.style.borderRightWidth
        val children = block.children.map { measure(it, innerWidth.coerceAtLeast(1f), imageSizes) }
        val height = stackHeight(children) + block.style.paddingTop + block.style.paddingBottom +
          block.style.borderTopWidth + block.style.borderBottomWidth
        MeasuredBlock(block, height, null, widthPx, children, emptyList(), emptyList())
      }

      is Block.ListBlock -> {
        val contentX = block.marginLeftPx + block.markerMarginLeftPx + block.markerWidthPx
        val contentWidth = (widthPx - contentX).coerceAtLeast(1f)
        val markerLayouts = ArrayList<StaticLayout>(block.rows.size)
        val rowContents = ArrayList<List<MeasuredBlock>>(block.rows.size)
        var height = 0f
        block.rows.forEachIndexed { index, row ->
          val marker = staticLayout(row.marker, row.markerPaint, block.markerWidthPx.toInt().coerceAtLeast(1), wrap = true)
          val content = row.content.map { measure(it, contentWidth, imageSizes) }
          markerLayouts.add(marker)
          rowContents.add(content)
          height += maxOf(marker.height.toFloat(), stackHeight(content))
          if (index < block.rows.size - 1) {
            height += gapPx / 2f
          }
        }
        MeasuredBlock(block, height, null, contentWidth, emptyList(), markerLayouts, rowContents)
      }

      is Block.Divider ->
        MeasuredBlock(block, block.thicknessPx, null, widthPx, emptyList(), emptyList(), emptyList())

      is Block.Image -> {
        val known = imageSizes[block.url]
        var displayH: Float
        var displayW: Float
        if (known != null && known[0] > 0 && known[1] > 0) {
          val intrinsicW = known[0] * density
          val intrinsicH = known[1] * density
          val scale = (widthPx / intrinsicW).coerceAtMost(1f)
          displayH = intrinsicH * scale
          if (block.heightPx > 0) {
            displayH = block.heightPx
          }
          if (block.maxHeightPx > 0) {
            displayH = displayH.coerceAtMost(block.maxHeightPx)
          }
          displayW = (intrinsicW * displayH / intrinsicH).coerceAtMost(widthPx)
        } else {
          displayH = if (block.heightPx > 0) block.heightPx else block.placeholderPx
          if (block.maxHeightPx > 0) {
            displayH = displayH.coerceAtMost(block.maxHeightPx)
          }
          displayW = block.placeholderPx.coerceAtMost(widthPx)
        }
        MeasuredBlock(block, displayH, null, displayW, emptyList(), emptyList(), emptyList())
      }
    }
  }

  private fun staticLayout(text: CharSequence, paint: TextPaint, widthPx: Int, wrap: Boolean): StaticLayout {
    return StaticLayout.Builder
      .obtain(text, 0, text.length, paint, widthPx.coerceAtLeast(1))
      .setAlignment(Layout.Alignment.ALIGN_NORMAL)
      .setIncludePad(false)
      .build()
  }
}
