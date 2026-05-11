package com.alizahid.markdown.view

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.view.View
import android.view.ViewGroup
import android.widget.HorizontalScrollView
import com.alizahid.markdown.parser.TableAlign
import com.alizahid.markdown.style.StyleConfig

/**
 * Block-level table view. Mirrors ios/views/MarkdownTableView: wraps a
 * grid in a HorizontalScrollView so wide tables scroll horizontally.
 * Cell borders and backgrounds come from the tableCell / tableHeaderCell
 * styles in the StyleConfig.
 */
class MarkdownTableView(
  context: Context,
  private val layout: MarkdownTableLayout,
  private val styleConfig: StyleConfig,
) : HorizontalScrollView(context) {

  init {
    isHorizontalScrollBarEnabled = false
    overScrollMode = OVER_SCROLL_NEVER
    addView(Grid(context), LayoutParams(layout.totalWidth, layout.totalHeight))
  }

  override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
    val widthSize = MeasureSpec.getSize(widthMeasureSpec)
    val resolvedWidth = if (MeasureSpec.getMode(widthMeasureSpec) == MeasureSpec.UNSPECIFIED)
      layout.totalWidth else widthSize.coerceAtMost(layout.totalWidth.coerceAtLeast(widthSize))
    val finalWidth = resolvedWidth.coerceAtMost(layout.totalWidth.coerceAtLeast(widthSize))
    setMeasuredDimension(
      if (layout.totalWidth > widthSize) widthSize else layout.totalWidth,
      layout.totalHeight,
    )
    measureChildren(
      MeasureSpec.makeMeasureSpec(layout.totalWidth, MeasureSpec.EXACTLY),
      MeasureSpec.makeMeasureSpec(layout.totalHeight, MeasureSpec.EXACTLY),
    )
  }

  /** Internal grid view that draws the cells + borders. */
  private inner class Grid(context: Context) : ViewGroup(context) {

    private val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }

    init {
      // Build text views for every cell — they live in the view tree so
      // they can be laid out, drawn, and (Phase 5) host overlays.
      val rows = layout.rows
      for (r in rows.indices) {
        val row = rows[r]
        for (c in row.cells.indices) {
          if (c >= layout.columnWidths.size) continue
          val cellStyle = if (row.isHeader) styleConfig.tableHeaderCell else styleConfig.tableCell
          val tv = MarkdownTextView(context).apply {
            text = row.cells[c].text
            val fs = if (!cellStyle.fontSize.isNaN() && cellStyle.fontSize > 0) cellStyle.fontSize
            else if (!styleConfig.base.fontSize.isNaN() && styleConfig.base.fontSize > 0) styleConfig.base.fontSize
            else 16f * resources.displayMetrics.density
            setTextSize(android.util.TypedValue.COMPLEX_UNIT_PX, fs)
            gravity = when (row.cells[c].align) {
              TableAlign.Center -> android.view.Gravity.CENTER_HORIZONTAL
              TableAlign.Right -> android.view.Gravity.END
              else -> android.view.Gravity.START
            }
            cellStyle.color?.let { setTextColor(it) }
          }
          addView(tv, LayoutParams(layout.columnWidths[c], layout.rowHeights[r]))
        }
      }
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
      var i = 0
      val rows = layout.rows
      val cellPad = 8
      for (r in rows.indices) {
        for (c in rows[r].cells.indices) {
          if (c >= layout.columnWidths.size) continue
          if (i >= childCount) break
          val cw = (layout.columnWidths[c] - cellPad * 2).coerceAtLeast(1)
          val ch = (layout.rowHeights[r] - cellPad * 2).coerceAtLeast(1)
          getChildAt(i).measure(
            MeasureSpec.makeMeasureSpec(cw, MeasureSpec.EXACTLY),
            MeasureSpec.makeMeasureSpec(ch, MeasureSpec.EXACTLY),
          )
          i++
        }
      }
      setMeasuredDimension(layout.totalWidth, layout.totalHeight)
    }

    override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
      val cellPad = 8
      var y = 0
      var i = 0
      val rows = layout.rows
      for (rIdx in rows.indices) {
        var x = 0
        val rowH = layout.rowHeights[rIdx]
        for (cIdx in rows[rIdx].cells.indices) {
          if (cIdx >= layout.columnWidths.size) continue
          if (i >= childCount) break
          val colW = layout.columnWidths[cIdx]
          getChildAt(i).layout(x + cellPad, y + cellPad, x + colW - cellPad, y + rowH - cellPad)
          x += colW
          i++
        }
        y += rowH
      }
    }

    override fun dispatchDraw(canvas: Canvas) {
      super.dispatchDraw(canvas)
      drawGridLines(canvas)
    }

    private fun drawGridLines(canvas: Canvas) {
      val cellStyle = styleConfig.tableCell
      val borderWidth = if (!cellStyle.borderWidth.isNaN() && cellStyle.borderWidth > 0)
        cellStyle.borderWidth else return
      val borderColor = cellStyle.borderColor ?: return
      borderPaint.strokeWidth = borderWidth
      borderPaint.color = borderColor

      // Vertical lines between columns + outer right
      var x = 0f
      for (c in layout.columnWidths.indices) {
        x += layout.columnWidths[c]
        canvas.drawLine(x, 0f, x, layout.totalHeight.toFloat(), borderPaint)
      }
      canvas.drawLine(0f, 0f, 0f, layout.totalHeight.toFloat(), borderPaint)
      // Horizontal lines between rows + outer top/bottom
      var y = 0f
      canvas.drawLine(0f, 0f, layout.totalWidth.toFloat(), 0f, borderPaint)
      for (r in layout.rowHeights.indices) {
        y += layout.rowHeights[r]
        canvas.drawLine(0f, y, layout.totalWidth.toFloat(), y, borderPaint)
      }
    }
  }
}
