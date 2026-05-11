package com.alizahid.markdown.view

import android.graphics.Typeface
import android.text.Layout
import android.text.Spanned
import android.text.StaticLayout
import android.text.TextPaint
import com.alizahid.markdown.parser.AstNode
import com.alizahid.markdown.parser.NodeType
import com.alizahid.markdown.parser.TableAlign
import com.alizahid.markdown.renderer.RenderContext
import com.alizahid.markdown.style.StyleConfig
import com.alizahid.markdown.util.TypefaceResolver
import kotlin.math.ceil
import kotlin.math.max

/**
 * Precomputed geometry for a Table AST node. Shared between the
 * measurer (which needs total Size) and the view layer (which needs to
 * lay out cells). Mirrors ios/views/MarkdownTableLayout.
 *
 * Strategy: each column gets the width needed by its widest cell when
 * unconstrained (its "natural" width). If the total fits in maxWidth we
 * just use those naturals; otherwise we keep them anyway and let the
 * HorizontalScrollView wrapper provide horizontal scroll.
 */
class MarkdownTableLayout private constructor(
  val rows: List<Row>,
  val columnWidths: IntArray,
  val rowHeights: IntArray,
  val totalWidth: Int,
  val totalHeight: Int,
) {
  data class Row(val cells: List<Cell>, val isHeader: Boolean)
  data class Cell(val text: Spanned, val align: TableAlign)

  companion object {
    private const val DEFAULT_CELL_PADDING_PX = 8
    private const val DEFAULT_MIN_COL_WIDTH_PX = 48

    fun compute(
      tableNode: AstNode,
      styleConfig: StyleConfig,
      customTags: Set<String>,
      maxWidth: Int,
    ): MarkdownTableLayout {
      val columnAligns = mutableListOf<TableAlign>()
      val rowsOut = mutableListOf<Row>()

      val baseTf = TypefaceResolver.resolve(styleConfig.base, Typeface.DEFAULT)
      val basePaint = TextPaint().apply {
        isAntiAlias = true
        typeface = baseTf
        textSize = if (!styleConfig.base.fontSize.isNaN() && styleConfig.base.fontSize > 0)
          styleConfig.base.fontSize else 16f
      }

      for (section in tableNode.children) {
        val isHeader = section.type == NodeType.TableHead
        for (rowNode in section.children) {
          if (rowNode.type != NodeType.TableRow) continue
          val cells = mutableListOf<Cell>()
          rowNode.children.forEachIndexed { idx, cellNode ->
            if (cellNode.type != NodeType.TableCell) return@forEachIndexed
            val text = RenderContext.renderNodeToSpanned(cellNode, styleConfig, customTags)
            if (idx >= columnAligns.size) columnAligns.add(cellNode.tableAlign)
            cells.add(Cell(text, cellNode.tableAlign))
          }
          rowsOut.add(Row(cells, isHeader))
        }
      }

      val colCount = columnAligns.size.coerceAtLeast(tableNode.tableColumnCount)
      val colWidths = IntArray(colCount) { DEFAULT_MIN_COL_WIDTH_PX }
      val cellPad = DEFAULT_CELL_PADDING_PX

      for (row in rowsOut) {
        row.cells.forEachIndexed { idx, cell ->
          if (idx >= colCount) return@forEachIndexed
          val natural = ceil(Layout.getDesiredWidth(cell.text, basePaint).toDouble()).toInt() + cellPad * 2
          colWidths[idx] = max(colWidths[idx], natural)
        }
      }

      val total = colWidths.sum()
      val rowHeights = IntArray(rowsOut.size) { rIdx ->
        val row = rowsOut[rIdx]
        var maxH = 0
        row.cells.forEachIndexed { idx, cell ->
          if (idx >= colCount) return@forEachIndexed
          val colW = (colWidths[idx] - cellPad * 2).coerceAtLeast(1)
          val l = StaticLayout.Builder.obtain(cell.text, 0, cell.text.length, basePaint, colW)
            .setAlignment(Layout.Alignment.ALIGN_NORMAL)
            .setIncludePad(false)
            .setLineSpacing(0f, 1f).build()
          maxH = max(maxH, l.height + cellPad * 2)
        }
        maxH
      }

      val totalHeight = rowHeights.sum()
      return MarkdownTableLayout(rowsOut, colWidths, rowHeights, total, totalHeight)
    }
  }
}
