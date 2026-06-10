package com.alizahid.markdown

import android.content.Context
import com.alizahid.markdown.measure.MarkdownMeasurer
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.ReactStylesDiffMap
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.StateWrapper
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.MarkdownViewManagerDelegate
import com.facebook.react.viewmanagers.MarkdownViewManagerInterface
import com.facebook.yoga.YogaMeasureMode
import com.facebook.yoga.YogaMeasureOutput

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

  /**
   * Yoga measure hook. Fabric calls this on the shadow thread to ask
   * "how tall is this component for the given width?" before computing
   * sibling layout — same role iOS's MarkdownViewShadowNode plays via
   * measureContent.
   *
   * Without this, Yoga assumes height = 0 for any `<Markdown>` with no
   * explicit `height`/`flex` style, so sibling Markdown instances
   * collapse onto each other and parent ScrollViews never learn there's
   * content to scroll past.
   *
   * We call into the shared MarkdownMeasurer, which renders the same
   * Spanned the runtime view does and uses StaticLayout for the height
   * computation — so the height Yoga reserves matches what the view
   * actually paints.
   */
  override fun measure(
    context: Context,
    localData: ReadableMap?,
    props: ReadableMap?,
    state: ReadableMap?,
    width: Float,
    widthMode: YogaMeasureMode,
    height: Float,
    heightMode: YogaMeasureMode,
    attachmentsPositions: FloatArray?,
  ): Long {
    val markdown = props?.getString("markdown") ?: ""
    if (props == null || markdown.isEmpty() || width <= 0f) {
      return YogaMeasureOutput.make(width, 0f)
    }
    // Yoga's measure callback hands us dp (Fabric's internal layout
    // unit); MarkdownMeasurer works in raw pixels (it builds the same
    // StaticLayout the view uses at runtime). Convert at the boundary
    // in both directions so Yoga + view both come out in their native
    // units.
    val density = context.resources.displayMetrics.density
    val styles = props.getString("styles")
    val customTags = props.getArray("customTags")?.let { arr ->
      buildSet { for (i in 0 until arr.size()) arr.getString(i)?.let { add(it) } }
    } ?: emptySet()
    val propImageSizes = props.getArray("images")?.let { arr ->
      buildMap {
        for (i in 0 until arr.size()) {
          val item = arr.getMap(i) ?: continue
          val url = item.getString("url") ?: continue
          val w = item.getDouble("width")
          val h = item.getDouble("height")
          if (w > 0 && h > 0) {
            put(url, android.util.Size((w * density).toInt(), (h * density).toInt()))
          }
        }
      }
    } ?: emptyMap()

    val widthPx = width * density
    val size = MarkdownMeasurer.measure(
      context, markdown, styles, customTags, propImageSizes, widthPx,
    )
    val heightDp = size.height / density
    android.util.Log.d(
      "MarkdownViewManager",
      "measure: w=${width}dp h=${heightDp}dp (px=${size.height}, density=$density) markdown=${markdown.take(60)}",
    )
    return YogaMeasureOutput.make(width, heightDp)
  }

  companion object {
    const val NAME = "MarkdownView"
  }
}
