const { withXcodeProject } = require('@expo/config-plugins')

/**
 * Expo config plugin for react-native-markdown.
 *
 * Sets CLANG_CXX_LANGUAGE_STANDARD to c++17 in the Xcode project
 * for the md4c C++ parser.
 */
function withMarkdown(config) {
  return withXcodeProject(config, (config) => {
    const xcodeProject = config.modResults
    const buildConfigurations =
      xcodeProject.pbxXCBuildConfigurationSection()

    for (const key in buildConfigurations) {
      const buildConfig = buildConfigurations[key]

      if (
        typeof buildConfig === 'object' &&
        buildConfig.buildSettings
      ) {
        buildConfig.buildSettings.CLANG_CXX_LANGUAGE_STANDARD =
          '"c++17"'
      }
    }

    return config
  })
}

module.exports = withMarkdown
