const path = require("node:path");
const pkg = require("../package.json");

module.exports = {
  dependencies: {
    [pkg.name]: {
      root: path.join(import.meta.dirname, ".."),
      platforms: {
        // Codegen script incorrectly fails without this
        // So we explicitly specify the platforms with empty object
        ios: {},
        android: {},
      },
    },
  },
};
