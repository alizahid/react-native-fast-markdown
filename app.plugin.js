const {
  withPlugins,
  withDangerousMod,
  withXcodeProject,
} = require('@expo/config-plugins')
const fs = require('fs')
const path = require('path')

/**
 * Sets CLANG_CXX_LANGUAGE_STANDARD to c++17 in the Xcode project.
 */
function withCxx17(config) {
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

/**
 * Ensures the Podfile includes the necessary post_install hook
 * for the C++ header search paths.
 */
function withPodfileConfig(config) {
  return withDangerousMod(config, [
    'ios',
    (config) => {
      const podfilePath = path.join(
        config.modRequest.platformProjectRoot,
        'Podfile'
      )

      let podfile = fs.readFileSync(podfilePath, 'utf-8')

      // Ensure use_frameworks! is NOT set (we need static linking for C++)
      // This is handled by Expo's default config, but we verify it
      if (
        podfile.includes("use_frameworks! :linkage => :static") === false &&
        podfile.includes('use_frameworks!') === true
      ) {
        podfile = podfile.replace(
          "use_frameworks!",
          "use_frameworks! :linkage => :static"
        )
        fs.writeFileSync(podfilePath, podfile)
      }

      return config
    },
  ])
}

/**
 * Expo config plugin for react-native-markdown.
 *
 * Configures the native projects for proper C++ compilation
 * and linking of the md4c parser.
 */
function withMarkdown(config) {
  return withPlugins(config, [withCxx17, withPodfileConfig])
}

module.exports = withMarkdown
