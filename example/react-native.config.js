/** biome-ignore-all lint/correctness/noGlobalDirnameFilename: CommonJS config — import.meta syntax flips Node module detection and breaks require() */
const path = require("node:path");
const pkg = require("../package.json");

module.exports = {
  dependencies: {
    [pkg.name]: {
      root: path.join(__dirname, ".."),
      platforms: {
        // Codegen script incorrectly fails without this
        // So we explicitly specify the platforms with empty object
        ios: {},
        android: {},
      },
    },
  },
};
