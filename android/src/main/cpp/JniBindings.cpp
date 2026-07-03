// JNI surface for com.fastmarkdown.FastMarkdownNative. This TU is linked
// into the app's libappmodules.so (which owns JNI_OnLoad), so natives are
// exported by name instead of registered from an OnLoad hook.
//
// Strings cross as UTF-8 byte arrays: JNI's NewStringUTF/GetStringUTFChars
// speak modified UTF-8 and corrupt supplementary characters (emoji).

#include <jni.h>

#include <string>
#include <vector>

#include "core/AstSerializer.h"
#include "core/Parser.h"
#include "react/FastMarkdownMeasurer.h"

namespace {

JavaVM* g_vm = nullptr;
jobject g_measurer = nullptr;
jmethodID g_measureMethod = nullptr;

std::string toStdString(JNIEnv* env, jbyteArray value) {
  if (value == nullptr) {
    return {};
  }
  const jsize length = env->GetArrayLength(value);
  std::string result(static_cast<size_t>(length), '\0');
  if (length > 0) {
    env->GetByteArrayRegion(value, 0, length, reinterpret_cast<jbyte*>(result.data()));
  }
  return result;
}

jbyteArray toByteArray(JNIEnv* env, const uint8_t* data, size_t size) {
  jbyteArray result = env->NewByteArray(static_cast<jsize>(size));
  if (result != nullptr && size > 0) {
    env->SetByteArrayRegion(
        result, 0, static_cast<jsize>(size), reinterpret_cast<const jbyte*>(data));
  }
  return result;
}

JNIEnv* currentEnv() {
  if (g_vm == nullptr) {
    return nullptr;
  }
  JNIEnv* env = nullptr;
  const jint state = g_vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6);
  if (state == JNI_EDETACHED) {
    if (g_vm->AttachCurrentThread(&env, nullptr) != JNI_OK) {
      return nullptr;
    }
  } else if (state != JNI_OK) {
    return nullptr;
  }
  return env;
}

} // namespace

extern "C" JNIEXPORT jbyteArray JNICALL
Java_com_fastmarkdown_FastMarkdownNative_parse(JNIEnv* env, jclass, jbyteArray markdown) {
  const std::string input = toStdString(env, markdown);
  const auto document = fastmarkdown::parseMarkdown(input);
  const std::vector<uint8_t> bytes = fastmarkdown::serializeAst(document->root);
  return toByteArray(env, bytes.data(), bytes.size());
}

extern "C" JNIEXPORT void JNICALL
Java_com_fastmarkdown_FastMarkdownNative_installMeasurer(
    JNIEnv* env,
    jclass,
    jobject measurer) {
  env->GetJavaVM(&g_vm);
  if (g_measurer != nullptr) {
    env->DeleteGlobalRef(g_measurer);
  }
  g_measurer = env->NewGlobalRef(measurer);

  jclass measurerClass = env->GetObjectClass(measurer);
  g_measureMethod = env->GetMethodID(measurerClass, "measure", "([B[B[BFF)F");
  env->DeleteLocalRef(measurerClass);

  fastmarkdown::FastMarkdownMeasurer::shared().install(
      [](const std::string& markdown,
         const std::string& stylesJson,
         const std::string& imagesJson,
         float maxWidth,
         float fontScale) -> float {
        JNIEnv* jniEnv = currentEnv();
        if (jniEnv == nullptr || g_measurer == nullptr || g_measureMethod == nullptr) {
          return 0.0f;
        }
        jbyteArray jMarkdown = toByteArray(
            jniEnv, reinterpret_cast<const uint8_t*>(markdown.data()), markdown.size());
        jbyteArray jStyles = toByteArray(
            jniEnv, reinterpret_cast<const uint8_t*>(stylesJson.data()), stylesJson.size());
        jbyteArray jImages = toByteArray(
            jniEnv, reinterpret_cast<const uint8_t*>(imagesJson.data()), imagesJson.size());
        const jfloat height = jniEnv->CallFloatMethod(
            g_measurer, g_measureMethod, jMarkdown, jStyles, jImages, maxWidth, fontScale);
        jniEnv->DeleteLocalRef(jMarkdown);
        jniEnv->DeleteLocalRef(jStyles);
        jniEnv->DeleteLocalRef(jImages);
        if (jniEnv->ExceptionCheck()) {
          jniEnv->ExceptionClear();
          return 0.0f;
        }
        return static_cast<float>(height);
      });
}
