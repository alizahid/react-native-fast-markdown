package com.alizahid.markdown.view

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.view.Gravity
import android.view.ViewGroup
import android.widget.HorizontalScrollView
import com.alizahid.markdown.parser.TableAlign
import com.alizahid.markdown.style.StyleConfig

/**
 * Block-level table view. Mirrors ios/views/MarkdownTableView: wraps a
 * precomputed grid in a HorizontalScrollView, paints row backgrounds
 * (tableHeaderRow / tableRow), draws grid borders from tableCell, and
 * lays out cells using padding insets from the style.
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
    setMeasuredDimension(
      if (layout.totalWidth > widthSize) widthSize else layout.totalWidth,
      layout.totalHeight,
    )
    measureChildren(
      MeasureSpec.makeMeasureSpec(layout.totalWidth, MeasureSpec.EXACTLY),
      MeasureSpec.makeMeasureSpec(layout.totalHeight, MeasureSpec.EXACTLY),
    )
  }

  private inner class Grid(context: Context) : ViewGroup(context) {

    private val rowBgPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }

    init {
      // Build a TextView per cell so the precomputed Spanned (already
      // styled via header/body inheritedAttrs) just renders.
      for (r in layout.rows.indices) {
        val row = layout.rows[r]
        val cellStyle = if (row.isHeader) styleConfig.tableHeaderCell else styleConfig.tableCell
        val baseAlignFallback = if (row.isHeader)
          (styleConfig.tableHeaderCell.textAlign ?: styleConfig.tableCell.textAlign)
        else styleConfig.tableCell.textAlign

        for (c in row.cells.indices) {
          if (c >= layout.columnWidths.size) continue
          val cell = row.cells[c]
          val tv = MarkdownTextView(context).apply {
            text = cell.text
            val fs = pickFontSize(cellStyle)
            setTextSize(android.util.TypedValue.COMPLEX_UNIT_PX, fs)
            gravity = when {
              cell.align == TableAlign.Center -> Gravity.CENTER_HORIZONTAL
              cell.align == TableAlign.Right -> Gravity.END
              cell.align == TableAlign.Left -> Gravity.START
              baseAlignFallback == "center" -> Gravity.CENTER_HORIZONTAL
              baseAlignFallback == "right" -> Gravity.END
              else -> Gravity.START
            }
          }
          addView(tv, LayoutParams(layout.columnWidths[c], layout.rowHeights[r]))
        }
      }
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
      var i = 0
      for (r in layout.rows.indices) {
        val row = layout.rows[r]
        val insets = if (row.isHeader) layout.headerInsets else layout.cellInsets
        for (c in row.cells.indices) {
          if (c >= layout.columnWidths.size) continue
          if (i >= childCount) break
          val cw = (layout.columnWidths[c] - insets.left - insets.right).coerceAtLeast(1)
          val ch = (layout.rowHeights[r] - insets.top - insets.bottom).coerceAtLeast(1)
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
      val border = layout.gridBorderWidth
      var y = border
      var i = 0
      for (rIdx in layout.rows.indices) {
        val row = layout.rows[rIdx]
        val insets = if (row.isHeader) layout.headerInsets else layout.cellInsets
        var x = border
        val rowH = layout.rowHeights[rIdx]
        for (cIdx in row.cells.indices) {
          if (cIdx >= layout.columnWidths.size) continue
          if (i >= childCount) break
          val colW = layout.columnWidths[cIdx]
          getChildAt(i).layout(
            x + insets.left, y + insets.top,
            x + colW - insets.right, y + rowH - insets.bottom,
          )
          x += colW + border
          i++
        }
        y += rowH + border
      }
    }

    override fun dispatchDraw(canvas: Canvas) {
      drawRowBackgrounds(canvas)
      super.dispatchDraw(canvas)
      drawGridLines(canvas)
    }

    private fun drawRowBackgrounds(canvas: Canvas) {
      val border = layout.gridBorderWidth
      var y = border.toFloat()
      for (rIdx in layout.rows.indices) {
        val row = layout.rows[rIdx]
        val rowH = layout.rowHeights[rIdx]
        val bg = if (row.isHeader)
          (styleConfig.tableHeaderRow.backgroundColor ?: styleConfig.tableRow.backgroundColor)
        else styleConfig.tableRow.backgroundColor
        if (bg != null) {
          rowBgPaint.color = bg
          canvas.drawRect(0f, y, layout.totalWidth.toFloat(), y + rowH, rowBgPaint)
        }
        y += rowH + border
      }
    }

    private fun drawGridLines(canvas: Canvas) {
      val border = layout.gridBorderWidth
      if (border <= 0) return
      val cellStyle = styleConfig.tableCell
      val borderColor = cellStyle.borderColor ?: return
      borderPaint.strokeWidth = border.toFloat()
      borderPaint.color = borderColor

      val half = border / 2f
      val w = layout.totalWidth.toFloat()
      val h = layout.totalHeight.toFloat()

      // Vertical lines: left edge + after each column + right edge.
      var x = half
      canvas.drawLine(x, 0f, x, h, borderPaint)
      for (c in layout.columnWidths.indices) {
        x += layout.columnWidths[c] + border
        canvas.drawLine(x - half * 2 + half, 0f, x - half * 2 + half, h, borderPaint)
      }

      // Horizontal lines: top edge + after each row + bottom edge.
      var y = half
      canvas.drawLine(0f, y, w, y, borderPaint)
      for (r in layout.rowHeights.indices) {
        y += layout.rowHeights[r] + border
        canvas.drawLine(0f, y - half * 2 + half, w, y - half * 2 + half, borderPaint)
      }
    }
  }

  private fun pickFontSize(style: com.alizahid.markdown.style.ElementStyle): Float {
    if (!style.fontSize.isNaN() && style.fontSize > 0) return style.fontSize
    if (!styleConfig.base.fontSize.isNaN() && styleConfig.base.fontSize > 0) return styleConfig.base.fontSize
    return 16f * resources.displayMetrics.density
  }
}
