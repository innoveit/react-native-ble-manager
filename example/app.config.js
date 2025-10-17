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
        NSAccessorySetupBluetoothCompanyIdentifiers: ['0x004C'],
        NSAccessorySetupBluetoothNames: ['MyAccessoryName'],
        NSAccessorySetupBluetoothServices: ['0x180D', '0x180F'],
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
