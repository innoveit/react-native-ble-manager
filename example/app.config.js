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
        NSAccessorySetupBluetoothCompanyIdentifiers: [],
        NSAccessorySetupBluetoothNames: ['MyAccessoryName'],
        NSAccessorySetupBluetoothServices: ['0x180D', '0x180F','0x2A37'],
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
