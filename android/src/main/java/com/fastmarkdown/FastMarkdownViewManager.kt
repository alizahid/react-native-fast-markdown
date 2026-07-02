package com.fastmarkdown

import android.graphics.Color
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.FastMarkdownViewManagerInterface
import com.facebook.react.viewmanagers.FastMarkdownViewManagerDelegate

@ReactModule(name = FastMarkdownViewManager.NAME)
class FastMarkdownViewManager : SimpleViewManager<FastMarkdownView>(),
  FastMarkdownViewManagerInterface<FastMarkdownView> {
  private val mDelegate: ViewManagerDelegate<FastMarkdownView>

  init {
    mDelegate = FastMarkdownViewManagerDelegate(this)
  }

  override fun getDelegate(): ViewManagerDelegate<FastMarkdownView>? {
    return mDelegate
  }

  override fun getName(): String {
    return NAME
  }

  public override fun createViewInstance(context: ThemedReactContext): FastMarkdownView {
    return FastMarkdownView(context)
  }

  @ReactProp(name = "color")
  override fun setColor(view: FastMarkdownView?, color: Int?) {
    view?.setBackgroundColor(color ?: Color.TRANSPARENT)
  }

  companion object {
    const val NAME = "FastMarkdownView"
  }
}
