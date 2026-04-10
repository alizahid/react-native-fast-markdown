module.exports = {
  dependency: {
    platforms: {
      android: {
        componentDescriptors: [
          'MarkdownViewComponentDescriptor',
          'MarkdownInputViewComponentDescriptor',
        ],
        cmakeListsPath: '../src/main/jni/CMakeLists.txt',
      },
    },
  },
}
