/**
 * @type {import('@react-native-community/cli-types').UserDependencyConfig}
 */
module.exports = {
  dependency: {
    platforms: {
      android: {
        sourceDir: './android',
      },
      ios: {
        podspecPath: './react-native-ble-manager.podspec',
      },
    },
  },
};
