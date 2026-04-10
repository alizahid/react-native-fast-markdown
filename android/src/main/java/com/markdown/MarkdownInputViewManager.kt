package com.markdown

import com.facebook.react.bridge.ReadableArray
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.MarkdownInputViewManagerDelegate
import com.facebook.react.viewmanagers.MarkdownInputViewManagerInterface

@ReactModule(name = MarkdownInputViewManager.NAME)
class MarkdownInputViewManager : SimpleViewManager<MarkdownInputView>(),
    MarkdownInputViewManagerInterface<MarkdownInputView> {

    companion object {
        const val NAME = "MarkdownInputView"
    }

    private val delegate = MarkdownInputViewManagerDelegate(this)

    override fun getDelegate(): ViewManagerDelegate<MarkdownInputView> = delegate

    override fun getName(): String = NAME

    override fun createViewInstance(context: ThemedReactContext): MarkdownInputView {
        return MarkdownInputView(context)
    }

    @ReactProp(name = "defaultValue")
    override fun setDefaultValue(view: MarkdownInputView, value: String?) {
        if (value != null && view.text.isEmpty()) {
            view.setText(value)
        }
    }

    @ReactProp(name = "placeholder")
    override fun setPlaceholder(view: MarkdownInputView, value: String?) {
        view.hint = value ?: ""
    }

    @ReactProp(name = "placeholderTextColor")
    override fun setPlaceholderTextColor(view: MarkdownInputView, value: String?) {
        // Apply placeholder color
    }

    @ReactProp(name = "markdownStyle")
    override fun setMarkdownStyle(view: MarkdownInputView, value: String?) {
        view.setMarkdownStyle(value ?: "")
    }

    @ReactProp(name = "customTags")
    override fun setCustomTags(view: MarkdownInputView, value: ReadableArray?) {
        val tags = mutableListOf<String>()
        value?.let {
            for (i in 0 until it.size()) {
                it.getString(i)?.let { tag -> tags.add(tag) }
            }
        }
        view.setCustomTags(tags)
    }

    @ReactProp(name = "editable", defaultBoolean = true)
    override fun setEditable(view: MarkdownInputView, value: Boolean) {
        view.isEnabled = value
    }

    @ReactProp(name = "multiline", defaultBoolean = true)
    override fun setMultiline(view: MarkdownInputView, value: Boolean) {
        view.isSingleLine = !value
    }

    @ReactProp(name = "autoFocus", defaultBoolean = false)
    override fun setAutoFocus(view: MarkdownInputView, value: Boolean) {
        if (value) view.requestFocus()
    }

    @ReactProp(name = "scrollEnabled", defaultBoolean = true)
    override fun setScrollEnabled(view: MarkdownInputView, value: Boolean) {
        view.isVerticalScrollBarEnabled = value
    }

    @ReactProp(name = "autoCapitalize")
    override fun setAutoCapitalize(view: MarkdownInputView, value: String?) {
        // Apply auto-capitalize setting
    }

    @ReactProp(name = "cursorColor")
    override fun setCursorColor(view: MarkdownInputView, value: String?) {
        // Apply cursor color
    }

    @ReactProp(name = "selectionColor")
    override fun setSelectionColor(view: MarkdownInputView, value: String?) {
        // Apply selection color
    }

    // --- Commands ---

    override fun focus(view: MarkdownInputView) {
        view.requestFocus()
    }

    override fun blur(view: MarkdownInputView) {
        view.clearFocus()
    }

    override fun setValue(view: MarkdownInputView, value: String) {
        view.setText(value)
    }

    override fun setSelection(view: MarkdownInputView, start: Int, end: Int) {
        view.setSelection(start, end)
    }

    override fun toggleBold(view: MarkdownInputView) = view.toggleBold()
    override fun toggleItalic(view: MarkdownInputView) = view.toggleItalic()
    override fun toggleStrikethrough(view: MarkdownInputView) = view.toggleStrikethrough()
    override fun toggleUnderline(view: MarkdownInputView) = view.toggleUnderline()
    override fun toggleCode(view: MarkdownInputView) = view.toggleCode()
    override fun toggleHeading(view: MarkdownInputView, level: Int) = view.toggleHeading(level)
    override fun toggleOrderedList(view: MarkdownInputView) = view.toggleOrderedList()
    override fun toggleUnorderedList(view: MarkdownInputView) = view.toggleUnorderedList()
    override fun toggleBlockquote(view: MarkdownInputView) = view.toggleBlockquote()

    override fun insertLink(view: MarkdownInputView, url: String, text: String) {
        view.insertLink(url, text)
    }

    override fun removeLink(view: MarkdownInputView) = view.removeLink()
    override fun insertMention(view: MarkdownInputView, user: String) = view.insertMention(user)
    override fun insertSpoiler(view: MarkdownInputView) = view.insertSpoiler()

    override fun insertCustomTag(view: MarkdownInputView, tag: String, propsJson: String) {
        view.insertCustomTag(tag, propsJson)
    }
}
