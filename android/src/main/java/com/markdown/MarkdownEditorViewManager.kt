package com.markdown

import com.facebook.react.bridge.ReadableArray
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.MarkdownEditorViewManagerDelegate
import com.facebook.react.viewmanagers.MarkdownEditorViewManagerInterface

@ReactModule(name = MarkdownEditorViewManager.NAME)
class MarkdownEditorViewManager : SimpleViewManager<MarkdownEditorView>(),
    MarkdownEditorViewManagerInterface<MarkdownEditorView> {

    companion object {
        const val NAME = "MarkdownEditorView"
    }

    private val delegate = MarkdownEditorViewManagerDelegate(this)

    override fun getDelegate(): ViewManagerDelegate<MarkdownEditorView> = delegate

    override fun getName(): String = NAME

    override fun createViewInstance(context: ThemedReactContext): MarkdownEditorView {
        return MarkdownEditorView(context)
    }

    @ReactProp(name = "defaultValue")
    override fun setDefaultValue(view: MarkdownEditorView, value: String?) {
        if (value != null && view.text.isEmpty()) {
            view.setText(value)
        }
    }

    @ReactProp(name = "placeholder")
    override fun setPlaceholder(view: MarkdownEditorView, value: String?) {
        view.hint = value ?: ""
    }

    @ReactProp(name = "placeholderTextColor")
    override fun setPlaceholderTextColor(view: MarkdownEditorView, value: String?) {
        // Apply placeholder color
    }

    @ReactProp(name = "styles")
    override fun setStyles(view: MarkdownEditorView, value: String?) {
        view.setMarkdownStyle(value ?: "")
    }

    @ReactProp(name = "customTags")
    override fun setCustomTags(view: MarkdownEditorView, value: ReadableArray?) {
        val tags = mutableListOf<String>()
        value?.let {
            for (i in 0 until it.size()) {
                it.getString(i)?.let { tag -> tags.add(tag) }
            }
        }
        view.setCustomTags(tags)
    }

    @ReactProp(name = "editable", defaultBoolean = true)
    override fun setEditable(view: MarkdownEditorView, value: Boolean) {
        view.isEnabled = value
    }

    @ReactProp(name = "multiline", defaultBoolean = true)
    override fun setMultiline(view: MarkdownEditorView, value: Boolean) {
        view.isSingleLine = !value
    }

    @ReactProp(name = "autoFocus", defaultBoolean = false)
    override fun setAutoFocus(view: MarkdownEditorView, value: Boolean) {
        if (value) view.requestFocus()
    }

    @ReactProp(name = "scrollEnabled", defaultBoolean = true)
    override fun setScrollEnabled(view: MarkdownEditorView, value: Boolean) {
        view.isVerticalScrollBarEnabled = value
    }

    @ReactProp(name = "autoCapitalize")
    override fun setAutoCapitalize(view: MarkdownEditorView, value: String?) {
        // Apply auto-capitalize setting
    }

    @ReactProp(name = "cursorColor")
    override fun setCursorColor(view: MarkdownEditorView, value: String?) {
        // Apply cursor color
    }

    @ReactProp(name = "selectionColor")
    override fun setSelectionColor(view: MarkdownEditorView, value: String?) {
        // Apply selection color
    }

    // --- Commands ---

    override fun focus(view: MarkdownEditorView) {
        view.requestFocus()
    }

    override fun blur(view: MarkdownEditorView) {
        view.clearFocus()
    }

    override fun setValue(view: MarkdownEditorView, value: String) {
        view.setText(value)
    }

    override fun setSelection(view: MarkdownEditorView, start: Int, end: Int) {
        view.setSelection(start, end)
    }

    override fun toggleBold(view: MarkdownEditorView) = view.toggleBold()
    override fun toggleItalic(view: MarkdownEditorView) = view.toggleItalic()
    override fun toggleStrikethrough(view: MarkdownEditorView) = view.toggleStrikethrough()
    override fun toggleCode(view: MarkdownEditorView) = view.toggleCode()
    override fun toggleHeading(view: MarkdownEditorView, level: Int) = view.toggleHeading(level)
    override fun toggleOrderedList(view: MarkdownEditorView) = view.toggleOrderedList()
    override fun toggleUnorderedList(view: MarkdownEditorView) = view.toggleUnorderedList()
    override fun toggleBlockquote(view: MarkdownEditorView) = view.toggleBlockquote()

    override fun insertLink(view: MarkdownEditorView, url: String, text: String) {
        view.insertLink(url, text)
    }

    override fun removeLink(view: MarkdownEditorView) = view.removeLink()
    override fun insertMention(view: MarkdownEditorView, user: String) = view.insertMention(user)
    override fun insertSpoiler(view: MarkdownEditorView) = view.insertSpoiler()

    override fun insertCustomTag(view: MarkdownEditorView, tag: String, propsJson: String) {
        view.insertCustomTag(tag, propsJson)
    }
}
