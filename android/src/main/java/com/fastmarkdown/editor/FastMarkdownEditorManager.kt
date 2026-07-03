package com.fastmarkdown.editor

import com.facebook.react.bridge.ReadableArray
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.StateWrapper
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.FastMarkdownEditorManagerDelegate
import com.facebook.react.viewmanagers.FastMarkdownEditorManagerInterface
import com.fastmarkdown.FastMarkdownNative

@ReactModule(name = FastMarkdownEditorManager.NAME)
class FastMarkdownEditorManager : SimpleViewManager<FastMarkdownEditorView>(),
  FastMarkdownEditorManagerInterface<FastMarkdownEditorView> {
  private val delegate: ViewManagerDelegate<FastMarkdownEditorView> =
    FastMarkdownEditorManagerDelegate(this)

  init {
    FastMarkdownNative.ensureInstalled()
  }

  override fun getDelegate(): ViewManagerDelegate<FastMarkdownEditorView> = delegate

  override fun getName(): String = NAME

  public override fun createViewInstance(context: ThemedReactContext): FastMarkdownEditorView {
    FastMarkdownNative.ensureInstalled()
    return FastMarkdownEditorView(context)
  }

  @ReactProp(name = "autoCapitalize")
  override fun setAutoCapitalize(view: FastMarkdownEditorView?, value: String?) {
    view?.setCapitalizeMode(value)
  }

  @ReactProp(name = "autoCorrect")
  override fun setAutoCorrect(view: FastMarkdownEditorView?, value: Boolean) {
    view?.setAutoCorrectEnabled(value)
  }

  @ReactProp(name = "autoFocus")
  override fun setAutoFocus(view: FastMarkdownEditorView?, value: Boolean) {
    view?.setAutoFocus(value)
  }

  @ReactProp(name = "cursorColor")
  override fun setCursorColor(view: FastMarkdownEditorView?, value: Int) {
    view?.setCursorColorInt(value)
  }

  @ReactProp(name = "defaultValue")
  override fun setDefaultValue(view: FastMarkdownEditorView?, value: String?) {
    view?.setDefaultValue(value)
  }

  @ReactProp(name = "editable")
  override fun setEditable(view: FastMarkdownEditorView?, value: Boolean) {
    view?.isEnabled = value
  }

  @ReactProp(name = "mentionTriggers")
  override fun setMentionTriggers(view: FastMarkdownEditorView?, value: ReadableArray?) {
    // Wired in E4.
  }

  @ReactProp(name = "multiline")
  override fun setMultiline(view: FastMarkdownEditorView?, value: Boolean) {
    view?.setMultiline(value)
  }

  @ReactProp(name = "placeholder")
  override fun setPlaceholder(view: FastMarkdownEditorView?, value: String?) {
    view?.setPlaceholderText(value)
  }

  @ReactProp(name = "placeholderTextColor")
  override fun setPlaceholderTextColor(view: FastMarkdownEditorView?, value: Int) {
    view?.setPlaceholderColor(value)
  }

  @ReactProp(name = "scrollEnabled")
  override fun setScrollEnabled(view: FastMarkdownEditorView?, value: Boolean) {
    view?.isVerticalScrollBarEnabled = value
  }

  @ReactProp(name = "selectionColor")
  override fun setSelectionColor(view: FastMarkdownEditorView?, value: Int) {
    view?.setSelectionColorInt(value)
  }

  @ReactProp(name = "stylesJson")
  override fun setStylesJson(view: FastMarkdownEditorView?, value: String?) {
    view?.setStylesJson(value)
  }

  override fun blur(view: FastMarkdownEditorView?) {
    view?.blurAndHideKeyboard()
  }

  override fun focus(view: FastMarkdownEditorView?) {
    view?.focusAndShowKeyboard()
  }

  override fun setSelection(view: FastMarkdownEditorView?, start: Int, end: Int) {
    view?.setEditorSelection(start, end)
  }

  override fun setValue(view: FastMarkdownEditorView?, value: String?) {
    view?.setMarkdownValue(value ?: "")
  }

  override fun toggleBlockQuote(view: FastMarkdownEditorView?) {
    view?.toggleBlock(EditorBlocks.QUOTE, 0)
  }

  override fun toggleBold(view: FastMarkdownEditorView?) {
    view?.toggleMark(EditorMarks.BOLD)
  }

  override fun toggleCodeBlock(view: FastMarkdownEditorView?) {
    view?.toggleBlock(EditorBlocks.CODE, 0)
  }

  override fun toggleHeading(view: FastMarkdownEditorView?, level: Int) {
    view?.toggleBlock(EditorBlocks.HEADING, level.coerceIn(1, 6))
  }

  override fun toggleOrderedList(view: FastMarkdownEditorView?) {
    view?.toggleBlock(EditorBlocks.ORDERED, 0)
  }

  override fun toggleUnorderedList(view: FastMarkdownEditorView?) {
    view?.toggleBlock(EditorBlocks.BULLET, 0)
  }

  override fun toggleCode(view: FastMarkdownEditorView?) {
    view?.toggleMark(EditorMarks.INLINE_CODE)
  }

  override fun toggleItalic(view: FastMarkdownEditorView?) {
    view?.toggleMark(EditorMarks.ITALIC)
  }

  override fun toggleSpoiler(view: FastMarkdownEditorView?) {
    view?.toggleMark(EditorMarks.SPOILER)
  }

  override fun toggleStrikethrough(view: FastMarkdownEditorView?) {
    view?.toggleMark(EditorMarks.STRIKETHROUGH)
  }

  override fun toggleSubscript(view: FastMarkdownEditorView?) {
    view?.toggleMark(EditorMarks.SUBSCRIPT)
  }

  override fun toggleSuperscript(view: FastMarkdownEditorView?) {
    view?.toggleMark(EditorMarks.SUPERSCRIPT)
  }

  override fun prepareToRecycleView(
    reactContext: ThemedReactContext,
    view: FastMarkdownEditorView,
  ): FastMarkdownEditorView {
    view.resetForRecycle()
    return view
  }

  override fun updateState(
    view: FastMarkdownEditorView,
    props: com.facebook.react.uimanager.ReactStylesDiffMap,
    stateWrapper: StateWrapper?,
  ): Any? {
    view.stateWrapper = stateWrapper
    return null
  }

  companion object {
    const val NAME = "FastMarkdownEditor"
  }
}
