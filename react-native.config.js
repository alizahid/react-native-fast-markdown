module.exports = {
  dependency: {
    platforms: {
      android: {
        packageImportPath: "import com.markdown.MarkdownPackage;",
        packageInstance: "new MarkdownPackage()",
        componentDescriptors: [
          "MarkdownViewComponentDescriptor",
          "MarkdownInputViewComponentDescriptor",
        ],
        cmakeListsPath: "src/main/jni/CMakeLists.txt",
      },
    },
  },
};
