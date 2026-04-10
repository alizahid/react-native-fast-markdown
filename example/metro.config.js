const { getDefaultConfig } = require('expo/metro-config')
const path = require('path')

const projectRoot = __dirname
const libraryRoot = path.resolve(projectRoot, '..')

const config = getDefaultConfig(projectRoot)

// Watch the library source alongside the example
config.watchFolders = [libraryRoot]

// Resolve modules from both the example and the library root
config.resolver.nodeModulesPaths = [
  path.resolve(projectRoot, 'node_modules'),
  path.resolve(libraryRoot, 'node_modules'),
]

module.exports = config
