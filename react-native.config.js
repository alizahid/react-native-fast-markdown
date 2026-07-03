module.exports = {
  dependency: {
    platforms: {
      android: {
        // Custom CMake target: compiles the codegen output plus the shared
        // C++ core and registers the custom measurable shadow node.
        cmakeListsPath: "CMakeLists.txt",
      },
    },
  },
};
