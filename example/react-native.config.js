const path = require('node:path')
const pkg = require('../package.json')

module.exports = {
  project: {
    ios: {
      automaticPodsInstallation: true,
    },
  },
  dependencies: {
    [pkg.name]: {
      // biome-ignore lint/correctness/noGlobalDirnameFilename: go away
      root: path.join(__dirname, '..'),
      platforms: {
        ios: {},
      },
    },
  },
}
