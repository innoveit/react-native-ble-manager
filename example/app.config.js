export default ({ config }) => {
  if (process.env.MY_ENVIRONMENT === 'production') {
    config.name = 'RN BLE Example';
  } else {
    config.name = 'RN BLE Example Dev';
  }

  return {
    ...config,
    android: {
      package: 'it.innove.example.ble',
    },
    ios: {
      bundleIdentifier: 'it.innove.example.ble',
      infoPlist: {
        NSAccessorySetupKitSupports: ['Bluetooth'],
        NSAccessorySetupBluetoothServices: [
          '0000180D-0000-1000-8000-00805F9B34FB',
        ],
        NSAccessorySetupBluetoothNames: ['Polar'],
      },
    },
    plugins: [
      [
        '../app.plugin.js',
        { companionDeviceEnabled: true, neverForLocation: true },
      ],
      'expo-build-properties',
    ],
  };
};
