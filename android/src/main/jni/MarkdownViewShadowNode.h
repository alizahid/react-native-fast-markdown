#pragma once

#include <fbjni/fbjni.h>
#include <react/renderer/components/MarkdownViewSpec/EventEmitters.h>
#include <react/renderer/components/MarkdownViewSpec/Props.h>
#include <react/renderer/components/view/ConcreteViewShadowNode.h>
#include <react/renderer/core/LayoutConstraints.h>
#include <react/renderer/core/LayoutContext.h>

namespace facebook::react {

extern const char MarkdownViewComponentName[];

class MarkdownViewShadowNode final
    : public ConcreteViewShadowNode<
          MarkdownViewComponentName,
          MarkdownViewProps,
          MarkdownViewEventEmitter> {
 public:
  using ConcreteViewShadowNode::ConcreteViewShadowNode;

  static ShadowNodeTraits BaseTraits() {
    auto traits = ConcreteViewShadowNode::BaseTraits();
    traits.set(ShadowNodeTraits::Trait::LeafYogaNode);
    traits.set(ShadowNodeTraits::Trait::MeasurableYogaNode);
    return traits;
  }

  Size measureContent(
      const LayoutContext &layoutContext,
      const LayoutConstraints &layoutConstraints) const override {
    const auto &props = getConcreteProps();

    Float maxWidth = layoutConstraints.maximumSize.width;
    Float density = layoutContext.pointScaleFactor;

    JNIEnv *env = jni::Environment::current();
    if (!env)
      return {maxWidth, 0};

    // Look up the Java measurer class and method (cached after first call)
    static jclass measurerClass = nullptr;
    static jmethodID measureMethod = nullptr;
    if (!measurerClass) {
      jclass local = env->FindClass("com/markdown/MarkdownMeasurer");
      if (!local)
        return {maxWidth, 0};
      measurerClass = (jclass)env->NewGlobalRef(local);
      env->DeleteLocalRef(local);
      measureMethod = env->GetStaticMethodID(
          measurerClass, "measure",
          "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;FF)[F");
    }

    jstring jMarkdown = env->NewStringUTF(props.markdown.c_str());
    jstring jStyles = env->NewStringUTF(props.styles.c_str());

    std::string tagsCsv;
    for (size_t i = 0; i < props.customTags.size(); i++) {
      if (i > 0)
        tagsCsv += ",";
      tagsCsv += props.customTags[i];
    }
    jstring jTags = env->NewStringUTF(tagsCsv.c_str());

    auto resultArray = (jfloatArray)env->CallStaticObjectMethod(
        measurerClass, measureMethod, jMarkdown, jStyles, jTags,
        (jfloat)maxWidth, (jfloat)density);

    env->DeleteLocalRef(jMarkdown);
    env->DeleteLocalRef(jStyles);
    env->DeleteLocalRef(jTags);

    if (!resultArray || env->ExceptionCheck()) {
      env->ExceptionClear();
      return {maxWidth, 0};
    }

    jfloat result[2];
    env->GetFloatArrayRegion(resultArray, 0, 2, result);
    env->DeleteLocalRef(resultArray);

    return layoutConstraints.clamp(
        {static_cast<Float>(result[0]), static_cast<Float>(result[1])});
  }
};

} // namespace facebook::react
