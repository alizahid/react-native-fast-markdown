package com.markdown

import com.facebook.react.bridge.ReadableArray
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.MarkdownViewManagerDelegate
import com.facebook.react.viewmanagers.MarkdownViewManagerInterface

@ReactModule(name = MarkdownViewManager.NAME)
class MarkdownViewManager : SimpleViewManager<MarkdownView>(),
    MarkdownViewManagerInterface<MarkdownView> {

    companion object {
        const val NAME = "MarkdownView"
    }

    private val delegate = MarkdownViewManagerDelegate(this)

    override fun getDelegate(): ViewManagerDelegate<MarkdownView> = delegate

    override fun getName(): String = NAME

    override fun createViewInstance(context: ThemedReactContext): MarkdownView {
        return MarkdownView(context)
    }

    @ReactProp(name = "markdown")
    override fun setMarkdown(view: MarkdownView, value: String?) {
        view.setMarkdown(value ?: "")
    }

    @ReactProp(name = "markdownStyle")
    override fun setMarkdownStyle(view: MarkdownView, value: String?) {
        view.setMarkdownStyle(value ?: "")
    }

    @ReactProp(name = "customTags")
    override fun setCustomTags(view: MarkdownView, value: ReadableArray?) {
        val tags = mutableListOf<String>()
        value?.let {
            for (i in 0 until it.size()) {
                it.getString(i)?.let { tag -> tags.add(tag) }
            }
        }
        view.setCustomTags(tags)
    }
}
