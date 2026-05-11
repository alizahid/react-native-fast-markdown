package com.alizahid.markdown.events

import android.view.View
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReactContext
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.events.Event

/**
 * Builds Fabric direct events for the four `MarkdownView` callbacks.
 * Event names match the codegen-emitted constants (`topLinkPress` etc.);
 * the ViewManager's `getExportedCustomDirectEventTypeConstants()` maps
 * those onto JS prop names (`onLinkPress`).
 */
object MarkdownEventDispatcher {

  fun dispatchLinkPress(view: View, url: String, title: String) =
    dispatch(view, "topLinkPress", linkPayload(url, title))

  fun dispatchLinkLongPress(view: View, url: String, title: String) =
    dispatch(view, "topLinkLongPress", linkPayload(url, title))

  fun dispatchImagePress(view: View, url: String, width: Int, height: Int) {
    val map = Arguments.createMap()
    map.putString("url", url)
    map.putDouble("width", width.toDouble())
    map.putDouble("height", height.toDouble())
    dispatch(view, "topImagePress", map)
  }

  fun dispatchMentionPress(
    view: View, type: String, id: String, name: String, propsJson: String,
  ) {
    val map = Arguments.createMap()
    map.putString("mentionType", type)
    map.putString("mentionId", id)
    map.putString("mentionName", name)
    map.putString("mentionProps", propsJson)
    dispatch(view, "topMentionPress", map)
  }

  private fun linkPayload(url: String, title: String): WritableMap {
    val map = Arguments.createMap()
    map.putString("url", url)
    map.putString("title", title)
    return map
  }

  private fun dispatch(view: View, eventName: String, payload: WritableMap) {
    val ctx = view.context as? ReactContext ?: return
    val surfaceId = UIManagerHelper.getSurfaceId(view)
    val dispatcher = UIManagerHelper.getEventDispatcherForReactTag(ctx, view.id) ?: return
    dispatcher.dispatchEvent(MarkdownEvent(surfaceId, view.id, eventName, payload))
  }

  private class MarkdownEvent(
    surfaceId: Int,
    viewTag: Int,
    private val eventName: String,
    private val payload: WritableMap,
  ) : Event<MarkdownEvent>(surfaceId, viewTag) {
    override fun getEventName(): String = eventName
    override fun getEventData(): WritableMap = payload
  }
}
