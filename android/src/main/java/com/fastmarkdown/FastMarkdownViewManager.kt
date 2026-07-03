package com.fastmarkdown

import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.StateWrapper
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.FastMarkdownViewManagerDelegate
import com.facebook.react.viewmanagers.FastMarkdownViewManagerInterface

@ReactModule(name = FastMarkdownViewManager.NAME)
class FastMarkdownViewManager : SimpleViewManager<FastMarkdownView>(),
  FastMarkdownViewManagerInterface<FastMarkdownView> {
  private val delegate: ViewManagerDelegate<FastMarkdownView> =
    FastMarkdownViewManagerDelegate(this)

  init {
    FastMarkdownNative.ensureInstalled()
  }

  override fun getDelegate(): ViewManagerDelegate<FastMarkdownView> = delegate

  override fun getName(): String = NAME

  public override fun createViewInstance(context: ThemedReactContext): FastMarkdownView {
    FastMarkdownNative.ensureInstalled()
    return FastMarkdownView(context)
  }

  @ReactProp(name = "markdown")
  override fun setMarkdown(view: FastMarkdownView?, value: String?) {
    view?.setMarkdown(value)
  }

  @ReactProp(name = "stylesJson")
  override fun setStylesJson(view: FastMarkdownView?, value: String?) {
    view?.setStylesJson(value)
  }

  @ReactProp(name = "images")
  override fun setImages(view: FastMarkdownView?, value: ReadableArray?) {
    view?.setImages(value)
  }

  override fun prepareToRecycleView(
    reactContext: ThemedReactContext,
    view: FastMarkdownView,
  ): FastMarkdownView {
    view.resetForRecycle()
    return view
  }

  override fun updateState(
    view: FastMarkdownView,
    props: com.facebook.react.uimanager.ReactStylesDiffMap,
    stateWrapper: StateWrapper?,
  ): Any? {
    view.stateWrapper = stateWrapper
    return null
  }

  companion object {
    const val NAME = "FastMarkdownView"
  }
}
