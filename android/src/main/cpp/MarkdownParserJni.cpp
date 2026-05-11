#include <jni.h>
#include <set>
#include <string>
#include <vector>

#include "ASTNode.hpp"
#include "MarkdownParser.hpp"

namespace {

struct JniRefs {
  jclass astNodeClass = nullptr;
  jmethodID astNodeCtor = nullptr;

  jclass nodeTypeClass = nullptr;
  jobjectArray nodeTypeValues = nullptr; // ordinal-indexed cache
  jclass listTypeClass = nullptr;
  jobjectArray listTypeValues = nullptr;
  jclass tableAlignClass = nullptr;
  jobjectArray tableAlignValues = nullptr;

  jclass arrayListClass = nullptr;
  jmethodID arrayListCtorInt = nullptr;
  jmethodID arrayListAdd = nullptr;

  jclass hashMapClass = nullptr;
  jmethodID hashMapCtorInt = nullptr;
  jmethodID hashMapPut = nullptr;

  jclass emptyListWrapperClass = nullptr;
  jmethodID emptyListMethod = nullptr;
  jclass emptyMapWrapperClass = nullptr;
  jmethodID emptyMapMethod = nullptr;
};

JniRefs g_refs;

jstring toJString(JNIEnv *env, const std::string &s) {
  return env->NewStringUTF(s.c_str());
}

jobject enumValueAt(JNIEnv *env, jobjectArray values, int ordinal) {
  return env->GetObjectArrayElement(values, ordinal);
}

jobject buildPropsMap(JNIEnv *env,
                     const std::map<std::string, std::string> &props) {
  if (props.empty()) {
    return env->CallStaticObjectMethod(g_refs.emptyMapWrapperClass,
                                       g_refs.emptyMapMethod);
  }
  jobject map = env->NewObject(g_refs.hashMapClass, g_refs.hashMapCtorInt,
                               static_cast<jint>(props.size()));
  for (const auto &kv : props) {
    jstring k = toJString(env, kv.first);
    jstring v = toJString(env, kv.second);
    jobject prev = env->CallObjectMethod(map, g_refs.hashMapPut, k, v);
    if (prev != nullptr) env->DeleteLocalRef(prev);
    env->DeleteLocalRef(k);
    env->DeleteLocalRef(v);
  }
  return map;
}

jobject buildAstNode(JNIEnv *env, const markdown::ASTNode &node);

jobject buildChildrenList(JNIEnv *env,
                         const std::vector<markdown::ASTNode> &children) {
  if (children.empty()) {
    return env->CallStaticObjectMethod(g_refs.emptyListWrapperClass,
                                       g_refs.emptyListMethod);
  }
  jobject list = env->NewObject(g_refs.arrayListClass,
                                g_refs.arrayListCtorInt,
                                static_cast<jint>(children.size()));
  for (const auto &child : children) {
    jobject c = buildAstNode(env, child);
    env->CallBooleanMethod(list, g_refs.arrayListAdd, c);
    env->DeleteLocalRef(c);
  }
  return list;
}

jobject buildAstNode(JNIEnv *env, const markdown::ASTNode &node) {
  jobject typeEnum =
      enumValueAt(env, g_refs.nodeTypeValues, static_cast<int>(node.type));
  jstring content = toJString(env, node.content);
  jobject listType =
      enumValueAt(env, g_refs.listTypeValues, static_cast<int>(node.listType));
  jstring codeLang = toJString(env, node.codeLanguage);
  jobject tableAlign = enumValueAt(env, g_refs.tableAlignValues,
                                   static_cast<int>(node.tableAlign));
  jstring linkUrl = toJString(env, node.linkUrl);
  jstring linkTitle = toJString(env, node.linkTitle);
  jstring imageSrc = toJString(env, node.imageSrc);
  jstring imageTitle = toJString(env, node.imageTitle);
  jstring tagName = toJString(env, node.tagName);
  jobject tagProps = buildPropsMap(env, node.tagProps);
  jobject children = buildChildrenList(env, node.children);

  jobject out = env->NewObject(
      g_refs.astNodeClass, g_refs.astNodeCtor, typeEnum, content,
      static_cast<jint>(node.headingLevel), listType,
      static_cast<jint>(node.listStart),
      static_cast<jboolean>(node.listTight ? JNI_TRUE : JNI_FALSE), codeLang,
      tableAlign, static_cast<jint>(node.tableColumnCount), linkUrl, linkTitle,
      imageSrc, imageTitle,
      static_cast<jboolean>(node.isAutolink ? JNI_TRUE : JNI_FALSE), tagName,
      tagProps, children);

  env->DeleteLocalRef(typeEnum);
  env->DeleteLocalRef(content);
  env->DeleteLocalRef(listType);
  env->DeleteLocalRef(codeLang);
  env->DeleteLocalRef(tableAlign);
  env->DeleteLocalRef(linkUrl);
  env->DeleteLocalRef(linkTitle);
  env->DeleteLocalRef(imageSrc);
  env->DeleteLocalRef(imageTitle);
  env->DeleteLocalRef(tagName);
  env->DeleteLocalRef(tagProps);
  env->DeleteLocalRef(children);

  return out;
}

jobjectArray cacheEnumValues(JNIEnv *env, jclass cls,
                             const char *enumDescriptor) {
  std::string sig = std::string("()[L") + enumDescriptor + ";";
  jmethodID m = env->GetStaticMethodID(cls, "values", sig.c_str());
  if (m == nullptr) return nullptr;
  jobjectArray local = (jobjectArray)env->CallStaticObjectMethod(cls, m);
  if (local == nullptr) return nullptr;
  jobjectArray globalRef = (jobjectArray)env->NewGlobalRef(local);
  env->DeleteLocalRef(local);
  return globalRef;
}

jclass cacheGlobalClass(JNIEnv *env, const char *name) {
  jclass local = env->FindClass(name);
  if (local == nullptr) return nullptr;
  jclass global = (jclass)env->NewGlobalRef(local);
  env->DeleteLocalRef(local);
  return global;
}

bool initJniRefs(JNIEnv *env) {
  g_refs.astNodeClass =
      cacheGlobalClass(env, "com/alizahid/markdown/parser/AstNode");
  if (g_refs.astNodeClass == nullptr) return false;

  g_refs.nodeTypeClass =
      cacheGlobalClass(env, "com/alizahid/markdown/parser/NodeType");
  if (g_refs.nodeTypeClass == nullptr) return false;
  g_refs.listTypeClass =
      cacheGlobalClass(env, "com/alizahid/markdown/parser/ListType");
  if (g_refs.listTypeClass == nullptr) return false;
  g_refs.tableAlignClass =
      cacheGlobalClass(env, "com/alizahid/markdown/parser/TableAlign");
  if (g_refs.tableAlignClass == nullptr) return false;

  g_refs.nodeTypeValues = cacheEnumValues(env, g_refs.nodeTypeClass,
                                          "com/alizahid/markdown/parser/NodeType");
  g_refs.listTypeValues = cacheEnumValues(env, g_refs.listTypeClass,
                                          "com/alizahid/markdown/parser/ListType");
  g_refs.tableAlignValues = cacheEnumValues(
      env, g_refs.tableAlignClass, "com/alizahid/markdown/parser/TableAlign");
  if (g_refs.nodeTypeValues == nullptr || g_refs.listTypeValues == nullptr ||
      g_refs.tableAlignValues == nullptr) {
    return false;
  }

  g_refs.astNodeCtor = env->GetMethodID(
      g_refs.astNodeClass, "<init>",
      "(Lcom/alizahid/markdown/parser/NodeType;Ljava/lang/String;I"
      "Lcom/alizahid/markdown/parser/ListType;IZLjava/lang/String;"
      "Lcom/alizahid/markdown/parser/TableAlign;ILjava/lang/String;"
      "Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Z"
      "Ljava/lang/String;Ljava/util/Map;Ljava/util/List;)V");
  if (g_refs.astNodeCtor == nullptr) return false;

  g_refs.arrayListClass = cacheGlobalClass(env, "java/util/ArrayList");
  g_refs.arrayListCtorInt =
      env->GetMethodID(g_refs.arrayListClass, "<init>", "(I)V");
  g_refs.arrayListAdd =
      env->GetMethodID(g_refs.arrayListClass, "add", "(Ljava/lang/Object;)Z");

  g_refs.hashMapClass = cacheGlobalClass(env, "java/util/HashMap");
  g_refs.hashMapCtorInt =
      env->GetMethodID(g_refs.hashMapClass, "<init>", "(I)V");
  g_refs.hashMapPut = env->GetMethodID(
      g_refs.hashMapClass, "put",
      "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");

  g_refs.emptyListWrapperClass = cacheGlobalClass(env, "java/util/Collections");
  g_refs.emptyListMethod = env->GetStaticMethodID(
      g_refs.emptyListWrapperClass, "emptyList", "()Ljava/util/List;");
  g_refs.emptyMapWrapperClass = g_refs.emptyListWrapperClass;
  g_refs.emptyMapMethod = env->GetStaticMethodID(
      g_refs.emptyMapWrapperClass, "emptyMap", "()Ljava/util/Map;");

  return true;
}

} // namespace

extern "C" JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *) {
  JNIEnv *env = nullptr;
  if (vm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6) != JNI_OK) {
    return JNI_ERR;
  }
  if (!initJniRefs(env)) return JNI_ERR;
  return JNI_VERSION_1_6;
}

extern "C" JNIEXPORT jobject JNICALL
Java_com_alizahid_markdown_jni_MarkdownParserJni_nativeParse(
    JNIEnv *env, jclass, jstring markdownStr, jobjectArray customTagsArray) {
  if (markdownStr == nullptr) return nullptr;

  const char *cstr = env->GetStringUTFChars(markdownStr, nullptr);
  std::string markdown(cstr == nullptr ? "" : cstr);
  if (cstr != nullptr) env->ReleaseStringUTFChars(markdownStr, cstr);

  markdown::ParseOptions options;
  options.enableTables = true;
  options.enableStrikethrough = true;
  options.enableAutolinks = true;

  if (customTagsArray != nullptr) {
    jsize n = env->GetArrayLength(customTagsArray);
    for (jsize i = 0; i < n; ++i) {
      auto tag = (jstring)env->GetObjectArrayElement(customTagsArray, i);
      if (tag == nullptr) continue;
      const char *t = env->GetStringUTFChars(tag, nullptr);
      if (t != nullptr) {
        options.customTags.insert(std::string(t));
        env->ReleaseStringUTFChars(tag, t);
      }
      env->DeleteLocalRef(tag);
    }
  }

  markdown::ASTNode root;
  try {
    root = markdown::MarkdownParser::parse(markdown, options);
  } catch (const std::exception &) {
    return nullptr;
  } catch (...) {
    return nullptr;
  }

  return buildAstNode(env, root);
}
