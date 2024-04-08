"use strict";
var __assign = (this && this.__assign) || function () {
    __assign = Object.assign || function(t) {
        for (var s, i = 1, n = arguments.length; i < n; i++) {
            s = arguments[i];
            for (var p in s) if (Object.prototype.hasOwnProperty.call(s, p))
                t[p] = s[p];
        }
        return t;
    };
    return __assign.apply(this, arguments);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.addBLEHardwareFeatureToManifest = exports.addCompanionPermissionToManifest = exports.addConnectPermissionToManifest = exports.addScanPermissionToManifest = exports.addLocationPermissionToManifest = exports.withBLEAndroidManifest = void 0;
var config_plugins_1 = require("expo/config-plugins");
var withBLEAndroidManifest = function (config, _a) {
    var isBackgroundEnabled = _a.isBackgroundEnabled, neverForLocation = _a.neverForLocation;
    return (0, config_plugins_1.withAndroidManifest)(config, function (config) {
        config.modResults = addLocationPermissionToManifest(config.modResults, neverForLocation);
        config.modResults = addScanPermissionToManifest(config.modResults, neverForLocation);
        config.modResults = addConnectPermissionToManifest(config.modResults, neverForLocation);
        config.modResults = addCompanionPermissionToManifest(config.modResults);
        if (isBackgroundEnabled) {
            config.modResults = addBLEHardwareFeatureToManifest(config.modResults);
        }
        return config;
    });
};
exports.withBLEAndroidManifest = withBLEAndroidManifest;
/**
 * Add location permissions
 *  - 'android.permission.ACCESS_COARSE_LOCATION' for Android SDK 28 (Android 9) and lower
 *  - 'android.permission.ACCESS_FINE_LOCATION' for Android SDK 29 (Android 10) and higher.
 *    From Android SDK 31 (Android 12) it might not be required if BLE is not used for location.
 */
function addLocationPermissionToManifest(androidManifest, neverForLocationSinceSdk31) {
    if (!Array.isArray(androidManifest.manifest['uses-permission-sdk-23'])) {
        androidManifest.manifest['uses-permission-sdk-23'] = [];
    }
    var optMaxSdkVersion = neverForLocationSinceSdk31
        ? {
            'android:maxSdkVersion': '30',
        }
        : {};
    if (!androidManifest.manifest['uses-permission-sdk-23'].find(function (item) {
        return item.$['android:name'] === 'android.permission.ACCESS_COARSE_LOCATION';
    })) {
        androidManifest.manifest['uses-permission-sdk-23'].push({
            $: __assign({ 'android:name': 'android.permission.ACCESS_COARSE_LOCATION' }, optMaxSdkVersion),
        });
    }
    if (!androidManifest.manifest['uses-permission-sdk-23'].find(function (item) {
        return item.$['android:name'] === 'android.permission.ACCESS_FINE_LOCATION';
    })) {
        androidManifest.manifest['uses-permission-sdk-23'].push({
            $: __assign({ 'android:name': 'android.permission.ACCESS_FINE_LOCATION' }, optMaxSdkVersion),
        });
    }
    return androidManifest;
}
exports.addLocationPermissionToManifest = addLocationPermissionToManifest;
/**
 * Add 'android.permission.BLUETOOTH_SCAN'.
 * Required since Android SDK 31 (Android 12).
 */
function addScanPermissionToManifest(androidManifest, neverForLocation) {
    var _a;
    if (!Array.isArray(androidManifest.manifest['uses-permission'])) {
        androidManifest.manifest['uses-permission'] = [];
    }
    if (!androidManifest.manifest['uses-permission'].find(function (item) { return item.$['android:name'] === 'android.permission.BLUETOOTH_SCAN'; })) {
        config_plugins_1.AndroidConfig.Manifest.ensureToolsAvailable(androidManifest);
        (_a = androidManifest.manifest['uses-permission']) === null || _a === void 0 ? void 0 : _a.push({
            $: __assign(__assign({ 'android:name': 'android.permission.BLUETOOTH_SCAN' }, (neverForLocation
                ? {
                    'android:usesPermissionFlags': 'neverForLocation',
                }
                : {})), { 'tools:targetApi': '31' }),
        });
    }
    return androidManifest;
}
exports.addScanPermissionToManifest = addScanPermissionToManifest;
function addConnectPermissionToManifest(androidManifest, neverForLocation) {
    var _a;
    if (!Array.isArray(androidManifest.manifest['uses-permission'])) {
        androidManifest.manifest['uses-permission'] = [];
    }
    if (!androidManifest.manifest['uses-permission'].find(function (item) { return item.$['android:name'] === 'android.permission.BLUETOOTH_CONNECT'; })) {
        config_plugins_1.AndroidConfig.Manifest.ensureToolsAvailable(androidManifest);
        (_a = androidManifest.manifest['uses-permission']) === null || _a === void 0 ? void 0 : _a.push({
            $: {
                'android:name': 'android.permission.BLUETOOTH_CONNECT',
            },
        });
    }
    return androidManifest;
}
exports.addConnectPermissionToManifest = addConnectPermissionToManifest;
function addCompanionPermissionToManifest(androidManifest) {
    var _a;
    if (!Array.isArray(androidManifest.manifest['uses-feature'])) {
        androidManifest.manifest['uses-feature'] = [];
    }
    if (!androidManifest.manifest['uses-feature'].find(function (item) {
        return item.$['android:name'] === 'android.software.companion_device_setup';
    })) {
        (_a = androidManifest.manifest['uses-feature']) === null || _a === void 0 ? void 0 : _a.push({
            $: {
                'android:name': 'android.software.companion_device_setup',
                'android:required': 'true',
            },
        });
    }
    return androidManifest;
}
exports.addCompanionPermissionToManifest = addCompanionPermissionToManifest;
// Add this line if your application always requires BLE. More info can be found on: https://developer.android.com/guide/topics/connectivity/bluetooth-le.html#permissions
function addBLEHardwareFeatureToManifest(androidManifest) {
    var _a;
    // Add `<uses-feature android:name="android.hardware.bluetooth_le" android:required="true"/>` to the AndroidManifest.xml
    if (!Array.isArray(androidManifest.manifest['uses-feature'])) {
        androidManifest.manifest['uses-feature'] = [];
    }
    if (!androidManifest.manifest['uses-feature'].find(function (item) { return item.$['android:name'] === 'android.hardware.bluetooth_le'; })) {
        (_a = androidManifest.manifest['uses-feature']) === null || _a === void 0 ? void 0 : _a.push({
            $: {
                'android:name': 'android.hardware.bluetooth_le',
                'android:required': 'true',
            },
        });
    }
    return androidManifest;
}
exports.addBLEHardwareFeatureToManifest = addBLEHardwareFeatureToManifest;
