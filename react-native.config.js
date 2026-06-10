module.exports = {
  dependency: {
    platforms: {
      android: {
        // Codegen library name (codegenConfig.name in package.json).
        libraryName: 'MarkdownViewSpec',
        // Registered by the autolinking-generated autolinking.cpp. Both
        // names resolve to android/src/main/jni/fabric/.../ComponentDescriptors.h
        // (which shadows the codegen default) — MarkdownView gets the
        // measuring descriptor so Yoga reserves real content height.
        componentDescriptors: [
          'MarkdownViewComponentDescriptor',
          'MarkdownEditorViewComponentDescriptor',
        ],
        // Built by the HOST APP's CMake (not the library's own
        // externalNativeBuild): compiles codegen output + the custom
        // Fabric shadow node / measurements manager.
        cmakeListsPath: 'src/main/jni/CMakeLists.txt',
      },
    },
  },
}
