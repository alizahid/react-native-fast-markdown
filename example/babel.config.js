// Library source resolution is handled by the exports condition in
// metro.config.js (react-native-fast-markdown-source), so no babel aliasing
// is needed here.
module.exports = function (api) {
  api.cache(true);

  return {
    presets: ['babel-preset-expo'],
  };
};
