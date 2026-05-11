package com.alizahid.markdown

import com.facebook.react.bridge.ReadableArray
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.ReactStylesDiffMap
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.StateWrapper
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.MarkdownViewManagerDelegate
import com.facebook.react.viewmanagers.MarkdownViewManagerInterface

/**
 * Fabric ViewManager. Forwards codegen-emitted prop setters onto the
 * MarkdownView instance and registers a measure function so Yoga can
 * size the component on the shadow thread using the same render path.
 */
@ReactModule(name = MarkdownViewManager.NAME)
class MarkdownViewManager :
  SimpleViewManager<MarkdownView>(),
  MarkdownViewManagerInterface<MarkdownView> {

  private val delegate = MarkdownViewManagerDelegate(this)

  override fun getDelegate(): ViewManagerDelegate<MarkdownView> = delegate
  override fun getName(): String = NAME
  override fun createViewInstance(reactContext: ThemedReactContext): MarkdownView =
    MarkdownView(reactContext)

  @ReactProp(name = "markdown")
  override fun setMarkdown(view: MarkdownView, value: String?) {
    view.setMarkdown(value)
  }

  @ReactProp(name = "styles")
  override fun setStyles(view: MarkdownView, value: String?) {
    view.setStyles(value)
  }

  @ReactProp(name = "customTags")
  override fun setCustomTags(view: MarkdownView, value: ReadableArray?) {
    view.setCustomTags(value)
  }

  @ReactProp(name = "images")
  override fun setImages(view: MarkdownView, value: ReadableArray?) {
    view.setImages(value)
  }

  override fun getExportedCustomDirectEventTypeConstants(): MutableMap<String, Any> =
    mutableMapOf(
      "topLinkPress" to mutableMapOf("registrationName" to "onLinkPress"),
      "topLinkLongPress" to mutableMapOf("registrationName" to "onLinkLongPress"),
      "topMentionPress" to mutableMapOf("registrationName" to "onMentionPress"),
      "topImagePress" to mutableMapOf("registrationName" to "onImagePress"),
    )

  override fun updateState(
    view: MarkdownView,
    props: ReactStylesDiffMap,
    stateWrapper: StateWrapper,
  ): Any? {
    view.stateWrapper = stateWrapper
    return null
  }

  companion object {
    const val NAME = "MarkdownView"
  }
}
