"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
var config_plugins_1 = require("expo/config-plugins");
var withBLEAndroidManifest_1 = require("./withBLEAndroidManifest");
var withBluetoothPermissions_1 = require("./withBluetoothPermissions");
/**
 * Apply BLE native configuration.
 */
var withBLE = function (config, props) {
    var _a;
    if (props === void 0) { props = {}; }
    var _props = props || {};
    var isBackgroundEnabled = false;
    var neverForLocation = (_a = _props.neverForLocation) !== null && _a !== void 0 ? _a : false;
    if ('bluetoothPeripheralPermission' in _props) {
        config_plugins_1.WarningAggregator.addWarningIOS('bluetoothPeripheralPermission', "The iOS permission `NSBluetoothPeripheralUsageDescription` is fully deprecated as of iOS 13 (lowest iOS version in Expo SDK 47+). Remove the `bluetoothPeripheralPermission` property from the `@config-plugins/react-native-ble-plx` config plugin.");
    }
    // iOS
    config = (0, withBluetoothPermissions_1.withBluetoothPermissions)(config, _props);
    // Android
    config = config_plugins_1.AndroidConfig.Permissions.withPermissions(config, [
        'android.permission.BLUETOOTH',
        'android.permission.BLUETOOTH_ADMIN',
        'android.permission.BLUETOOTH_CONNECT', // since Android SDK 31
    ]);
    config = (0, withBLEAndroidManifest_1.withBLEAndroidManifest)(config, {
        isBackgroundEnabled: isBackgroundEnabled,
        neverForLocation: neverForLocation,
    });
    return config;
};
module.exports.withBLE = withBLE;
