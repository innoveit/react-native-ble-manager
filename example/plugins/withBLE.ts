import { AndroidConfig, ConfigPlugin, WarningAggregator } from 'expo/config-plugins';

import { withBLEAndroidManifest } from './withBLEAndroidManifest';
import { withBluetoothPermissions } from './withBluetoothPermissions';

/**
 * Apply BLE native configuration.
 */
const withBLE: ConfigPlugin<
   {
      neverForLocation?: boolean;
      bluetoothAlwaysPermission?: string | false;
   } | void
> = (config, props = {}) => {
   const _props = props || {};
   const isBackgroundEnabled = false;
   const neverForLocation = _props.neverForLocation ?? false;

   if ('bluetoothPeripheralPermission' in _props) {
      WarningAggregator.addWarningIOS(
         'bluetoothPeripheralPermission',
         `The iOS permission \`NSBluetoothPeripheralUsageDescription\` is fully deprecated as of iOS 13 (lowest iOS version in Expo SDK 47+). Remove the \`bluetoothPeripheralPermission\` property from the \`@config-plugins/react-native-ble-plx\` config plugin.`
      );
   }

   // iOS
   config = withBluetoothPermissions(config, _props);

   // Android
   config = AndroidConfig.Permissions.withPermissions(config, [
      'android.permission.BLUETOOTH',
      'android.permission.BLUETOOTH_ADMIN',
      'android.permission.BLUETOOTH_CONNECT', // since Android SDK 31
   ]);
   config = withBLEAndroidManifest(config, {
      isBackgroundEnabled,
      neverForLocation,
   });

   return config;
};

module.exports.withBLE = withBLE;
