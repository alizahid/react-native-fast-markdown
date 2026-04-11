import path from 'node:path'
import pkg from '../package.json'

module.exports = {
  project: {
    ios: {
      automaticPodsInstallation: true,
    },
  },
  dependencies: {
    [pkg.name]: {
      root: path.join(import.meta.dirname, '..'),
      platforms: {
        ios: {},
        android: {},
      },
    },
  },
}
