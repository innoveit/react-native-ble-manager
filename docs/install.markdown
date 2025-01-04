---
layout: page
title: Install
permalink: /install/
nav_order: 2
---

# Install

The library support the react native autolink feature.

```shell
npm i --save react-native-ble-manager
```

To use BLE in your app, you need to set specific permissions.

## Android

Update your manifest file

```xml
// file: android/app/src/main/AndroidManifest.xml
<!-- Add xmlns:tools -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools"
    package="YOUR_PACKAGE_NAME">

    <!--
      HACK: this permission should not be needed on android 12+ devices anymore,
      but in fact some manufacturers still need it for BLE to properly work :
      https://stackoverflow.com/a/72370969
    -->
    <uses-permission android:name="android.permission.BLUETOOTH" tools:remove="android:maxSdkVersion" />
    <!--
      should normally only be needed on android < 12 if you want to:
      - activate bluetooth programmatically
      - discover local BLE devices
      see: https://developer.android.com/guide/topics/connectivity/bluetooth/permissions#discover-local-devices.
      Same as above, may still be wrongly needed by some manufacturers on android 12+.
     -->
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" tools:remove="android:maxSdkVersion" />

    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" android:maxSdkVersion="28"/>
    <uses-permission-sdk-23 android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30"/>

    <!-- Only when targeting Android 12 or higher -->
    <!--
      Please make sure you read the following documentation
      to have a better understanding of the new permissions.
      https://developer.android.com/guide/topics/connectivity/bluetooth/permissions#assert-never-for-location
    -->

    <!-- Needed if your app search for Bluetooth devices. -->
     <!--
      If your app doesn't use Bluetooth scan results to derive physical location information,
      you can strongly assert that your app doesn't derive physical location.
    -->
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN"
                     android:usesPermissionFlags="neverForLocation" />
    <!-- Needed if you want to interact with a BLE device. -->
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <!-- Needed if your app makes the current device discoverable to other Bluetooth devices. -->
    <uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
...
```

If you need communication while the app is not in the foreground you need the `ACCESS_BACKGROUND_LOCATION` permission.

If you are working with Beacons remove the `android:usesPermissionFlags="neverForLocation"`.

For more information, refer to the [official documentation](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions).

Runtime permissions must also be requested from users using `PermissionsAndroid`, check the [example](https://github.com/innoveit/react-native-ble-manager/blob/master/example/components/ScanDevicesScreen.tsx).


## iOS

Update the Info.plist file.

In iOS >= 13 you need to add the `NSBluetoothAlwaysUsageDescription` string key.

If the deployment target is earlier than iOS 13, you also need to add the `NSBluetoothPeripheralUsageDescription` string key.

For background use you nedd to add `central-peripheral` in `UIBackgroundModes` key. Refer to the [documentation](https://developer.apple.com/documentation/xcode/configuring-background-execution-modes/).
