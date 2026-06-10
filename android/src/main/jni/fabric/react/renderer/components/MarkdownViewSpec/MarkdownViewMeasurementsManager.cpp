#include "MarkdownViewMeasurementsManager.h"

#include <fbjni/fbjni.h>
#include <folly/dynamic.h>
#include <react/jni/ReadableNativeMap.h>
#include <react/renderer/core/conversions.h>

using namespace facebook::jni;

namespace facebook::react {

Size MarkdownViewMeasurementsManager::measure(
    SurfaceId surfaceId,
    const MarkdownViewProps& props,
    LayoutConstraints layoutConstraints) const {
  const jni::global_ref<jobject>& fabricUIManager =
      contextContainer_->at<jni::global_ref<jobject>>("FabricUIManager");

  static auto measure =
      jni::findClassStatic("com/facebook/react/fabric/FabricUIManager")
          ->getMethod<jlong(
              jint,
              jstring,
              ReadableMap::javaobject,
              ReadableMap::javaobject,
              ReadableMap::javaobject,
              jfloat,
              jfloat,
              jfloat,
              jfloat)>("measure");

  auto minimumSize = layoutConstraints.minimumSize;
  auto maximumSize = layoutConstraints.maximumSize;

  local_ref<JString> componentName = make_jstring("MarkdownView");

  // Serialize only the props the Java measurer reads. Values stay in
  // the units JS sent them (dp) — MarkdownViewManager.measure converts
  // to raw pixels at its boundary.
  folly::dynamic serializedProps = folly::dynamic::object();
  serializedProps["markdown"] = props.markdown;
  serializedProps["styles"] = props.styles;

  folly::dynamic customTags = folly::dynamic::array();
  for (const auto& tag : props.customTags) {
    customTags.push_back(tag);
  }
  serializedProps["customTags"] = std::move(customTags);

  folly::dynamic images = folly::dynamic::array();
  for (const auto& image : props.images) {
    folly::dynamic entry = folly::dynamic::object();
    entry["url"] = image.url;
    entry["width"] = image.width;
    entry["height"] = image.height;
    images.push_back(std::move(entry));
  }
  serializedProps["images"] = std::move(images);

  local_ref<ReadableNativeMap::javaobject> propsRNM =
      ReadableNativeMap::newObjectCxxArgs(serializedProps);
  local_ref<ReadableMap::javaobject> propsRM =
      make_local(reinterpret_cast<ReadableMap::javaobject>(propsRNM.get()));

  return yogaMeassureToSize(measure(
      fabricUIManager,
      surfaceId,
      componentName.get(),
      nullptr,
      propsRM.get(),
      nullptr,
      minimumSize.width,
      maximumSize.width,
      minimumSize.height,
      maximumSize.height));
}

} // namespace facebook::react
