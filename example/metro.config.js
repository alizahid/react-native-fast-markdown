const { getDefaultConfig } = require('expo/metro-config')
const path = require('node:path')

// biome-ignore lint/correctness/noGlobalDirnameFilename: CJS file
const projectRoot = __dirname
const libraryRoot = path.resolve(projectRoot, '..')

const config = getDefaultConfig(projectRoot)

// Watch the library source alongside the example
config.watchFolders = [libraryRoot]

// Resolve all modules from the example's node_modules first
config.resolver.nodeModulesPaths = [
  path.resolve(projectRoot, 'node_modules'),
  path.resolve(libraryRoot, 'node_modules'),
]

// Block the library root's react/react-native to prevent duplicates
config.resolver.blockList = [
  new RegExp(
    `${path
      .resolve(libraryRoot, 'node_modules', '(react|react-native)')
      .replace(/[/\\]/g, '[/\\\\]')}[/\\\\].*`,
  ),
]

module.exports = config
