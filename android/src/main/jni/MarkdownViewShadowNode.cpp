#include "MarkdownViewShadowNode.h"

#include <fbjni/fbjni.h>
#include <react/renderer/core/LayoutConstraints.h>
#include <react/renderer/core/LayoutContext.h>

namespace facebook::react {

const char MarkdownViewComponentName[] = "MarkdownView";
const char MarkdownEditorViewComponentName[] = "MarkdownEditorView";

// Cache the JNI references so we only look them up once.
static struct {
  jclass clazz = nullptr;
  jmethodID method = nullptr;
} gMeasurer;

static void ensureMeasurerJNI(JNIEnv *env) {
  if (gMeasurer.clazz != nullptr)
    return;
  jclass local = env->FindClass("com/markdown/MarkdownMeasurer");
  gMeasurer.clazz = (jclass)env->NewGlobalRef(local);
  env->DeleteLocalRef(local);
  gMeasurer.method = env->GetStaticMethodID(
      gMeasurer.clazz, "measure",
      "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;FF)[F");
}

Size MarkdownViewShadowNode::measureContent(
    const LayoutContext &layoutContext,
    const LayoutConstraints &layoutConstraints) const {
  const auto &props = getConcreteProps();

  Float maxWidth = layoutConstraints.maximumSize.width;
  Float density = layoutContext.pointScaleFactor;

  // Attach the current thread to the JVM if needed (Yoga layout
  // thread is not the main thread).
  JNIEnv *env = nullptr;
  auto jvm = jni::Environment::current();
  env = jni::Environment::current();

  if (!env)
    return {maxWidth, 0};

  ensureMeasurerJNI(env);

  jstring jMarkdown = env->NewStringUTF(props.markdown.c_str());
  jstring jStyles = env->NewStringUTF(props.styles.c_str());

  // Build comma-separated custom tags string
  std::string tagsCsv;
  for (size_t i = 0; i < props.customTags.size(); i++) {
    if (i > 0)
      tagsCsv += ",";
    tagsCsv += props.customTags[i];
  }
  jstring jTags = env->NewStringUTF(tagsCsv.c_str());

  auto resultArray = (jfloatArray)env->CallStaticObjectMethod(
      gMeasurer.clazz, gMeasurer.method, jMarkdown, jStyles, jTags,
      (jfloat)maxWidth, (jfloat)density);

  env->DeleteLocalRef(jMarkdown);
  env->DeleteLocalRef(jStyles);
  env->DeleteLocalRef(jTags);

  if (!resultArray)
    return {maxWidth, 0};

  jfloat result[2];
  env->GetFloatArrayRegion(resultArray, 0, 2, result);
  env->DeleteLocalRef(resultArray);

  return layoutConstraints.clamp(
      {static_cast<Float>(result[0]), static_cast<Float>(result[1])});
}

} // namespace facebook::react
