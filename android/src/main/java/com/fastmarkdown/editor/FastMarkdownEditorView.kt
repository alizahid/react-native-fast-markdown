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
      override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit

      override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) = Unit

      override fun afterTextChanged(s: Editable?) {
        publishHeight()
        emitEvent("topEditorChangeText") { putString("text", s?.toString() ?: "") }
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
        // E0: plain text; E1 parses markdown into formatted content.
        setText(value)
        setSelection(text.length)
      }
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
