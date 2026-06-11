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
import com.alizahid.markdown.style.ElementStyle
import com.alizahid.markdown.style.StyleConfig
import com.alizahid.markdown.util.TypefaceResolver
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min

/**
 * Precomputed geometry for a Table AST node. Shared between the
 * measurer (which needs total Size) and the view layer (which needs to
 * lay out cells). Mirrors ios/views/MarkdownTableView.computeLayout
 * field-for-field: row contents are rendered with header / body
 * inheritedAttrs so header cells inherit headerCell font + color; row /
 * cell backgrounds, padding, and grid borders all come from the style
 * config rather than hardcoded constants.
 */
class MarkdownTableLayout private constructor(
  val rows: List<Row>,
  val columnWidths: IntArray,
  val rowHeights: IntArray,
  val cellInsets: android.graphics.Rect,
  val headerInsets: android.graphics.Rect,
  val gridBorderWidth: Int,
  val totalWidth: Int,
  val totalHeight: Int,
) {
  data class Row(val cells: List<Cell>, val isHeader: Boolean)
  data class Cell(val text: Spanned, val align: TableAlign)

  companion object {
    private const val MIN_COL_WIDTH_DP = 60f
    private const val MAX_COL_WIDTH_RATIO = 0.8f

    fun compute(
      tableNode: AstNode,
      styleConfig: StyleConfig,
      customTags: Set<String>,
      maxWidth: Int,
      density: Float,
    ): MarkdownTableLayout {
      val cellStyle = styleConfig.tableCell
      val headerCellStyle = styleConfig.tableHeaderCell

      // Cascade base + cell + header-cell attrs for header rows; base +
      // cell for body rows. The renderer's leaf attribute application
      // (applyAttributes) then writes the right font/color spans on
      // every text run inside the cell.
      val baseAttrs = RenderContext.baseAttributesFromStyleConfig(styleConfig)
      val bodyAttrs = RenderContext.mergeStyleAttrs(cellStyle, baseAttrs)
      val headerAttrs = RenderContext.mergeStyleAttrs(headerCellStyle, bodyAttrs)

      // Collect rows preserving header order.
      val rowsOut = mutableListOf<Row>()
      var colCount = 0
      for (section in tableNode.children) {
        val isHeader = section.type == NodeType.TableHead
        when (section.type) {
          NodeType.TableHead, NodeType.TableBody -> {
            for (rowNode in section.children) {
              if (rowNode.type != NodeType.TableRow) continue
              val cells = renderRow(rowNode, styleConfig, customTags,
                if (isHeader) headerAttrs else bodyAttrs)
              colCount = max(colCount, cells.size)
              rowsOut.add(Row(cells, isHeader))
            }
          }
          NodeType.TableRow -> {
            val cells = renderRow(section, styleConfig, customTags, bodyAttrs)
            colCount = max(colCount, cells.size)
            rowsOut.add(Row(cells, isHeader = false))
          }
          else -> {}
        }
      }

      if (rowsOut.isEmpty() || colCount == 0) {
        return MarkdownTableLayout(
          rows = emptyList(),
          columnWidths = IntArray(0),
          rowHeights = IntArray(0),
          cellInsets = android.graphics.Rect(),
          headerInsets = android.graphics.Rect(),
          gridBorderWidth = 0,
          totalWidth = 0,
          totalHeight = 0,
        )
      }

      val cellInsets = cellStyle.resolvedPaddingInsets()
      val headerInsetsRaw = headerCellStyle.resolvedPaddingInsets()
      val headerInsets = if (headerInsetsRaw.left == 0 && headerInsetsRaw.top == 0 &&
        headerInsetsRaw.right == 0 && headerInsetsRaw.bottom == 0) cellInsets else headerInsetsRaw
      // iOS uses the cellStyle border for grid lines (table.border draws
      // the outer wrap in MarkdownBlockView). Match.
      val gridBorderWidth = if (!cellStyle.borderWidth.isNaN() && cellStyle.borderWidth > 0)
        cellStyle.borderWidth.toInt() else 0

      // Cell paints — header cells get headerCell's typeface + size so
      // "120k" measures with the bold metrics.
      val baseTf = TypefaceResolver.resolve(styleConfig.base, Typeface.DEFAULT)
      val cellPaint = paintFor(styleConfig, cellStyle, baseTf, density)
      val headerPaint = paintFor(styleConfig, headerCellStyle, baseTf, density)

      val maxColWidth = (maxWidth * MAX_COL_WIDTH_RATIO).toInt()
      val minColWidth = (MIN_COL_WIDTH_DP * density).toInt()

      val colWidths = IntArray(colCount) { minColWidth }
      for (row in rowsOut) {
        val insets = if (row.isHeader) headerInsets else cellInsets
        val paint = if (row.isHeader) headerPaint else cellPaint
        row.cells.forEachIndexed { idx, cell ->
          if (idx >= colCount) return@forEachIndexed
          val natural = ceil(Layout.getDesiredWidth(cell.text, paint).toDouble()).toInt() +
            insets.left + insets.right
          colWidths[idx] = max(colWidths[idx], natural)
        }
      }
      for (c in colWidths.indices) colWidths[c] = min(colWidths[c], maxColWidth)

      val totalWidth = colWidths.sum() + gridBorderWidth * (colCount + 1)

      val rowHeights = IntArray(rowsOut.size) { rIdx ->
        val row = rowsOut[rIdx]
        val insets = if (row.isHeader) headerInsets else cellInsets
        val paint = if (row.isHeader) headerPaint else cellPaint
        var maxH = 0
        row.cells.forEachIndexed { idx, cell ->
          if (idx >= colCount) return@forEachIndexed
          val colW = (colWidths[idx] - insets.left - insets.right).coerceAtLeast(1)
          val l = StaticLayout.Builder.obtain(cell.text, 0, cell.text.length, paint, colW)
            .setAlignment(Layout.Alignment.ALIGN_NORMAL)
            .setIncludePad(false)
            .setLineSpacing(0f, 1f).build()
          maxH = max(maxH, l.height + insets.top + insets.bottom)
        }
        maxH
      }

      val totalHeight = rowHeights.sum() + gridBorderWidth * (rowsOut.size + 1)

      return MarkdownTableLayout(
        rows = rowsOut,
        columnWidths = colWidths,
        rowHeights = rowHeights,
        cellInsets = cellInsets,
        headerInsets = headerInsets,
        gridBorderWidth = gridBorderWidth,
        totalWidth = totalWidth,
        totalHeight = totalHeight,
      )
    }

    private fun renderRow(
      rowNode: AstNode,
      styleConfig: StyleConfig,
      customTags: Set<String>,
      inheritedAttrs: Map<String, Any?>,
    ): List<Cell> {
      val cells = mutableListOf<Cell>()
      for (cellNode in rowNode.children) {
        if (cellNode.type != NodeType.TableCell) continue
        val text = RenderContext.renderNodeToSpanned(
          cellNode, styleConfig, customTags, inheritedAttrs,
        )
        cells.add(Cell(text, cellNode.tableAlign))
      }
      return cells
    }

    private fun paintFor(
      cfg: StyleConfig, style: ElementStyle, baseTf: Typeface, density: Float,
    ): TextPaint = TextPaint().apply {
      isAntiAlias = true
      typeface = TypefaceResolver.resolve(style, baseTf)
      textSize = when {
        !style.fontSize.isNaN() && style.fontSize > 0 -> style.fontSize
        !cfg.base.fontSize.isNaN() && cfg.base.fontSize > 0 -> cfg.base.fontSize
        else -> 16f * density
      }
    }
  }
}
