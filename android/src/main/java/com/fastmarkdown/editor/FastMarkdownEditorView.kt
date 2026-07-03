package com.fastmarkdown.editor

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.os.Build
import android.text.Editable
import android.text.InputType
import android.text.Spanned
import android.text.TextPaint
import android.text.TextWatcher
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReactContext
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.StateWrapper
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.events.Event
import com.fastmarkdown.FastMarkdownNative
import com.fastmarkdown.style.StyleConfig

/**
 * WYSIWYG markdown editor: an EditText that publishes its content height
 * into the shadow-node state (autogrow) and emits editing events. Root text
 * attributes come from the same base/paragraph cascade the viewer uses.
 */
@SuppressLint("AppCompatCustomView")
class FastMarkdownEditorView(context: Context) : EditText(context) {
  var stateWrapper: StateWrapper? = null

  private var stylesJson: String = ""
  private var defaultValueApplied = false
  private var multiline = true
  private var autoCorrectEnabled = true
  private var capitalizeMode = "sentences"
  private var pendingAutoFocus = false
  private var lastPublishedHeight = 0f

  // Marks armed for text typed at the collapsed cursor; re-derived from the
  // character before the caret whenever the selection moves outside an edit.
  private var pendingMarks = 0
  private var lastStateFlags = -1
  private var editInProgress = false
  private var suppressWatcher = false
  private var changeStart = 0
  private var changeInserted = 0

  // Drawn manually: Fabric never drives onMeasure, and TextView's native
  // hint rendering depends on measure-time layout construction.
  private var placeholderText: String? = null
  private var placeholderColor: Int = 0x4D000000
  private val placeholderPaint = TextPaint(Paint.ANTI_ALIAS_FLAG)

  private val density = context.resources.displayMetrics.density

  // Fabric assigns exact frames and never runs a parent measure/layout pass,
  // so TextView's internal Layout is not rebuilt after programmatic setText
  // or hint changes. Re-run measure/layout in place against the current
  // frame (the standard fix for text-bearing custom views under Fabric).
  private val measureAndLayout = Runnable {
    if (width > 0 && height > 0) {
      measure(
        MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY),
        MeasureSpec.makeMeasureSpec(height, MeasureSpec.EXACTLY),
      )
      layout(left, top, right, bottom)
    }
  }

  override fun requestLayout() {
    super.requestLayout()
    post(measureAndLayout)
  }

  init {
    background = null
    gravity = Gravity.TOP or Gravity.START
    applyTextStyles()
    applyInputType()

    addTextChangedListener(object : TextWatcher {
      override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {
        editInProgress = true
      }

      override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
        changeStart = start
        changeInserted = count
      }

      override fun afterTextChanged(s: Editable?) {
        editInProgress = false
        if (suppressWatcher) {
          return
        }
        if (s != null && changeInserted > 0 && pendingMarks != 0) {
          for (mark in EditorMarks.ALL) {
            if (pendingMarks and mark != 0) {
              applyMark(s, mark, changeStart, changeStart + changeInserted)
            }
          }
        }
        if (s != null) {
          refreshDisplaySpans(s)
        }
        emitContentChanged()
      }
    })

    setOnFocusChangeListener { _, hasFocus ->
      emitEvent(if (hasFocus) "topEditorFocus" else "topEditorBlur") { }
    }
  }

  // Root text attributes: base (style prop text keys) then paragraph,
  // floored at 16pt black — the same cascade root the viewer uses.
  private fun applyTextStyles() {
    val styles = StyleConfig.from(stylesJson)

    var fontSize = 16f
    var fontFamily: String? = null
    var color = Color.BLACK
    for (key in listOf("base", "paragraph")) {
      val spec = styles.textStyleFor(key) ?: continue
      spec.fontSize?.let { fontSize = it }
      spec.fontFamily?.let { fontFamily = it }
      spec.color?.let { color = it }
    }

    setTextSize(TypedValue.COMPLEX_UNIT_PX, fontSize * density)
    setTextColor(color)
    typeface = fontFamily?.let { Typeface.create(it, Typeface.NORMAL) } ?: Typeface.DEFAULT

    setPadding(
      (styles.paddingLeft * density).toInt(),
      (styles.paddingTop * density).toInt(),
      (styles.paddingRight * density).toInt(),
      (styles.paddingBottom * density).toInt(),
    )
    styles.backgroundColor?.let { setBackgroundColor(it) }

    publishHeight()
  }

  // Setting inputType resets the typeface, so callers reapply styles after.
  private fun applyInputType() {
    var type = InputType.TYPE_CLASS_TEXT
    if (multiline) {
      type = type or InputType.TYPE_TEXT_FLAG_MULTI_LINE
    }
    if (autoCorrectEnabled) {
      type = type or InputType.TYPE_TEXT_FLAG_AUTO_CORRECT
    }
    type = type or when (capitalizeMode) {
      "words" -> InputType.TYPE_TEXT_FLAG_CAP_WORDS
      "characters" -> InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS
      "none" -> 0
      else -> InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
    }
    val selection = selectionStart
    inputType = type
    isSingleLine = !multiline
    if (selection >= 0 && selection <= text.length) {
      setSelection(selection)
    }
    applyTextStyles()
  }

  fun setStylesJson(value: String?) {
    val json = value ?: ""
    if (json != stylesJson) {
      stylesJson = json
      applyTextStyles()
    }
  }

  fun setDefaultValue(value: String?) {
    if (!defaultValueApplied) {
      defaultValueApplied = true
      if (!value.isNullOrEmpty()) {
        setMarkdownValue(value)
      }
    }
  }

  /** Parsed as markdown into text + inline-mark spans. */
  fun setMarkdownValue(markdown: String) {
    val (content, runs) = FastMarkdownNative.styledFromMarkdown(markdown)
    suppressWatcher = true
    setText(content)
    suppressWatcher = false
    val editable = text
    applyRuns(editable, runs)
    refreshDisplaySpans(editable)
    setSelection(text.length)
    emitContentChanged()
  }

  private fun applyRuns(editable: Editable, runs: IntArray) {
    var index = 0
    while (index + 3 <= runs.size) {
      val start = runs[index].coerceIn(0, editable.length)
      val end = runs[index + 1].coerceIn(start, editable.length)
      val flags = runs[index + 2]
      if (end > start) {
        for (mark in EditorMarks.ALL) {
          if (flags and mark != 0) {
            editable.setSpan(
              EditorMarkSpan(mark),
              start,
              end,
              Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
            )
          }
        }
      }
      index += 3
    }
  }

  /** Toggles a mark over the selection, or arms it for typed text. */
  fun toggleMark(mark: Int) {
    val start = selectionStart.coerceAtLeast(0)
    val end = selectionEnd.coerceAtLeast(start)
    if (start == end) {
      pendingMarks = pendingMarks xor mark
      emitState()
      return
    }
    val editable = text
    if (commonMarksInRange(editable, start, end) and mark != 0) {
      removeMark(editable, mark, start, end)
    } else {
      applyMark(editable, mark, start, end)
    }
    refreshDisplaySpans(editable)
    setSelection(start, end)
    emitContentChanged()
    emitState()
  }

  /** Adds a mark over [start, end), merging with touching same-mark spans. */
  private fun applyMark(editable: Editable, mark: Int, start: Int, end: Int) {
    var newStart = start
    var newEnd = end
    for (span in editable.getSpans(start, end, EditorMarkSpan::class.java)) {
      if (span.mark != mark) {
        continue
      }
      newStart = minOf(newStart, editable.getSpanStart(span))
      newEnd = maxOf(newEnd, editable.getSpanEnd(span))
      editable.removeSpan(span)
    }
    editable.setSpan(
      EditorMarkSpan(mark),
      newStart,
      newEnd,
      Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
    )
  }

  private fun removeMark(editable: Editable, mark: Int, start: Int, end: Int) {
    for (span in editable.getSpans(start, end, EditorMarkSpan::class.java)) {
      if (span.mark != mark) {
        continue
      }
      val spanStart = editable.getSpanStart(span)
      val spanEnd = editable.getSpanEnd(span)
      editable.removeSpan(span)
      if (spanStart < start) {
        editable.setSpan(
          EditorMarkSpan(mark),
          spanStart,
          start,
          Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
        )
      }
      if (spanEnd > end) {
        editable.setSpan(
          EditorMarkSpan(mark),
          end,
          spanEnd,
          Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
        )
      }
    }
  }

  /** Marks present across the ENTIRE range (the AND). */
  private fun commonMarksInRange(editable: Editable, start: Int, end: Int): Int {
    var common = 0
    for (mark in EditorMarks.ALL) {
      val intervals = editable.getSpans(start, end, EditorMarkSpan::class.java)
        .filter { it.mark == mark }
        .map { editable.getSpanStart(it) to editable.getSpanEnd(it) }
        .sortedBy { it.first }
      var covered = start
      for ((spanStart, spanEnd) in intervals) {
        if (spanStart > covered) {
          break
        }
        covered = maxOf(covered, spanEnd)
      }
      if (covered >= end) {
        common = common or mark
      }
    }
    return common
  }

  private fun marksAt(editable: Editable, position: Int): Int {
    if (position < 0 || position >= editable.length) {
      return 0
    }
    var flags = 0
    for (span in editable.getSpans(position, position + 1, EditorMarkSpan::class.java)) {
      if (editable.getSpanStart(span) <= position && editable.getSpanEnd(span) > position) {
        flags = flags or span.mark
      }
    }
    return flags
  }

  /**
   * Rebuilds the visual spans from the data spans: boundary points from all
   * mark spans partition the text into constant-flag intervals.
   */
  private fun refreshDisplaySpans(editable: Editable) {
    for (span in editable.getSpans(0, editable.length, EditorDisplaySpan::class.java)) {
      editable.removeSpan(span)
    }
    val marks = editable.getSpans(0, editable.length, EditorMarkSpan::class.java)
    if (marks.isEmpty()) {
      return
    }
    val cuts = sortedSetOf(0, editable.length)
    for (span in marks) {
      cuts.add(editable.getSpanStart(span).coerceIn(0, editable.length))
      cuts.add(editable.getSpanEnd(span).coerceIn(0, editable.length))
    }
    val points = cuts.toIntArray()
    for (i in 0 until points.size - 1) {
      val start = points[i]
      val end = points[i + 1]
      if (end <= start) {
        continue
      }
      var flags = 0
      for (span in marks) {
        if (editable.getSpanStart(span) <= start && editable.getSpanEnd(span) >= end) {
          flags = flags or span.mark
        }
      }
      if (flags != 0) {
        editable.setSpan(
          EditorDisplaySpan(flags),
          start,
          end,
          Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
        )
      }
    }
  }

  private fun serializedMarkdown(): String {
    val editable = text
    val spans = editable.getSpans(0, editable.length, EditorMarkSpan::class.java)
    val runs = IntArray(spans.size * 3)
    for ((index, span) in spans.withIndex()) {
      runs[index * 3] = editable.getSpanStart(span)
      runs[index * 3 + 1] = editable.getSpanEnd(span)
      runs[index * 3 + 2] = span.mark
    }
    return FastMarkdownNative.markdownFromStyled(editable.toString(), runs)
  }

  private fun emitContentChanged() {
    publishHeight()
    emitEvent("topEditorChangeText") { putString("text", text.toString()) }
    emitEvent("topEditorChangeMarkdown") { putString("markdown", serializedMarkdown()) }
  }

  private fun emitState() {
    val start = selectionStart.coerceAtLeast(0)
    val end = selectionEnd.coerceAtLeast(start)
    val flags = if (start == end) pendingMarks else commonMarksInRange(text, start, end)
    if (flags == lastStateFlags) {
      return
    }
    lastStateFlags = flags
    emitEvent("topEditorChangeState") {
      putInt("headingLevel", 0)
      putBoolean("isBlockQuote", false)
      putBoolean("isBold", flags and EditorMarks.BOLD != 0)
      putBoolean("isCodeBlock", false)
      putBoolean("isInlineCode", flags and EditorMarks.INLINE_CODE != 0)
      putBoolean("isItalic", flags and EditorMarks.ITALIC != 0)
      putBoolean("isOrderedList", false)
      putBoolean("isSpoiler", flags and EditorMarks.SPOILER != 0)
      putBoolean("isStrikethrough", flags and EditorMarks.STRIKETHROUGH != 0)
      putBoolean("isSubscript", flags and EditorMarks.SUBSCRIPT != 0)
      putBoolean("isSuperscript", flags and EditorMarks.SUPERSCRIPT != 0)
      putBoolean("isUnorderedList", false)
    }
  }

  fun setMultiline(value: Boolean) {
    if (multiline != value) {
      multiline = value
      applyInputType()
    }
  }

  fun setAutoCorrectEnabled(value: Boolean) {
    if (autoCorrectEnabled != value) {
      autoCorrectEnabled = value
      applyInputType()
    }
  }

  fun setCapitalizeMode(value: String?) {
    val mode = value ?: "sentences"
    if (capitalizeMode != mode) {
      capitalizeMode = mode
      applyInputType()
    }
  }

  fun setPlaceholderText(value: String?) {
    if (placeholderText != value) {
      placeholderText = value
      invalidate()
    }
  }

  fun setPlaceholderColor(value: Int) {
    if (value != 0 && placeholderColor != value) {
      placeholderColor = value
      invalidate()
    }
  }

  override fun onDraw(canvas: Canvas) {
    super.onDraw(canvas)
    val hint = placeholderText
    if (!hint.isNullOrEmpty() && text.isEmpty()) {
      placeholderPaint.textSize = textSize
      placeholderPaint.typeface = typeface
      placeholderPaint.color = placeholderColor
      canvas.drawText(
        hint,
        compoundPaddingLeft.toFloat(),
        compoundPaddingTop - placeholderPaint.fontMetrics.top,
        placeholderPaint,
      )
    }
  }

  fun setCursorColorInt(value: Int) {
    if (value != 0 && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      textCursorDrawable?.setTint(value)
    }
  }

  fun setSelectionColorInt(value: Int) {
    if (value != 0) {
      highlightColor = value
    }
  }

  fun setAutoFocus(value: Boolean) {
    pendingAutoFocus = value
    if (value && isAttachedToWindow) {
      focusAndShowKeyboard()
    }
  }

  fun setEditorSelection(start: Int, end: Int) {
    val length = text.length
    val clampedStart = start.coerceIn(0, length)
    val clampedEnd = end.coerceIn(clampedStart, length)
    setSelection(clampedStart, clampedEnd)
  }

  fun focusAndShowKeyboard() {
    requestFocus()
    val manager =
      context.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
    manager?.showSoftInput(this, InputMethodManager.SHOW_IMPLICIT)
  }

  fun blurAndHideKeyboard() {
    clearFocus()
    val manager =
      context.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
    manager?.hideSoftInputFromWindow(windowToken, 0)
  }

  fun resetForRecycle() {
    setText("")
    stylesJson = ""
    defaultValueApplied = false
    pendingAutoFocus = false
    lastPublishedHeight = 0f
    pendingMarks = 0
    lastStateFlags = -1
    stateWrapper = null
    applyTextStyles()
  }

  override fun onAttachedToWindow() {
    super.onAttachedToWindow()
    if (pendingAutoFocus) {
      pendingAutoFocus = false
      post { focusAndShowKeyboard() }
    }
  }

  override fun onSelectionChanged(selStart: Int, selEnd: Int) {
    super.onSelectionChanged(selStart, selEnd)
    // Sticky typing state: inherit the marks of the character before the
    // caret. Skipped mid-edit — afterTextChanged has not applied the pending
    // marks to the inserted text yet, so reading here would clear them.
    if (!editInProgress && selStart == selEnd && text != null) {
      pendingMarks = marksAt(text, selStart - 1)
    }
    emitState()
    emitEvent("topEditorChangeSelection") {
      putInt("start", selStart)
      putInt("end", selEnd)
    }
  }

  override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
    super.onLayout(changed, left, top, right, bottom)
    publishHeight()
  }

  private fun publishHeight() {
    val wrapper = stateWrapper ?: return
    val currentWidth = width
    if (currentWidth <= 0) {
      return
    }
    measure(
      MeasureSpec.makeMeasureSpec(currentWidth, MeasureSpec.EXACTLY),
      MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED),
    )
    val heightDp = measuredHeight / density
    if (kotlin.math.abs(heightDp - lastPublishedHeight) < 0.5f) {
      return
    }
    lastPublishedHeight = heightDp
    wrapper.updateState(Arguments.createMap().apply { putDouble("height", heightDp.toDouble()) })
  }

  private inline fun emitEvent(name: String, crossinline builder: WritableMap.() -> Unit) {
    val reactContext = context as? ReactContext ?: return
    val dispatcher = UIManagerHelper.getEventDispatcherForReactTag(reactContext, id) ?: return
    val surfaceId = UIManagerHelper.getSurfaceId(reactContext)
    dispatcher.dispatchEvent(object : Event<Nothing>(surfaceId, id) {
      override fun getEventName(): String = name

      override fun getEventData(): WritableMap = Arguments.createMap().apply(builder)
    })
  }
}
