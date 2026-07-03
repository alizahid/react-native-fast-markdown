const path = require("node:path");
const { getDefaultConfig } = require("expo/metro-config");
const { withMetroConfig } = require("react-native-monorepo-config");

const root = path.resolve(import.meta.dirname, "..");

/**
 * Metro configuration
 * https://facebook.github.io/metro/docs/configuration
 *
 * @type {import('metro-config').MetroConfig}
 */
const config = withMetroConfig(getDefaultConfig(import.meta.dirname), {
  root,
  dirname: import.meta.dirname,
  conditions: ["react-native-fast-markdown-source"],
});

module.exports = config;
