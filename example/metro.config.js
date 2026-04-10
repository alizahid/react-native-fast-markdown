const { getDefaultConfig } = require('expo/metro-config')
const path = require('path')

const projectRoot = __dirname
const libraryRoot = path.resolve(projectRoot, '..')

const config = getDefaultConfig(projectRoot)

// Watch the library source alongside the example
config.watchFolders = [libraryRoot]

// Ensure react and react-native resolve from the example only (no duplicates)
config.resolver.extraNodeModules = {
  react: path.resolve(projectRoot, 'node_modules/react'),
  'react-native': path.resolve(projectRoot, 'node_modules/react-native'),
}

module.exports = config
