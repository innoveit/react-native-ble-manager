# react-native-ble-manager

[![npm version](https://img.shields.io/npm/v/react-native-ble-manager.svg?style=flat)](https://www.npmjs.com/package/react-native-ble-manager)
[![npm downloads](https://img.shields.io/npm/dm/react-native-ble-manager.svg?style=flat)](https://www.npmjs.com/package/react-native-ble-manager)
[![GitHub issues](https://img.shields.io/github/issues/innoveit/react-native-ble-manager.svg?style=flat)](https://github.com/innoveit/react-native-ble-manager/issues)

A React Native Bluetooth Low Energy library.

Originally inspired by https://github.com/don/cordova-plugin-ble-central.

## Introduction

The library is a simple connection with the OS APIs, the BLE stack should be standard but often has different behaviors based on the device used, the operating system and the BLE chip it connects to. Before opening an issue verify that the problem is really the library.

## Requirements

RN 0.60+

RN 0.40-0.59 supported until 6.7.X
RN 0.30-0.39 supported until 2.4.3

## Supported Platforms

- iOS 8+
- Android (API 19+)

## Install

```shell
npm i --save react-native-ble-manager
```
The library support the react native autolink feature.


##### Android - Update Manifest

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

If you need communication while the app is not in the foreground you need the "ACCESS_BACKGROUND_LOCATION" permission.

##### iOS - Update Info.plist

In iOS >= 13 you need to add the `NSBluetoothAlwaysUsageDescription` string key.

## Note

- Remember to use the `start` method before anything.
- If you have problem with old devices try avoid to connect/read/write to a peripheral during scan.
- Android API >= 23 require the ACCESS_COARSE_LOCATION permission to scan for peripherals. React Native >= 0.33 natively support PermissionsAndroid like in the example.
- Android API >= 29 require the ACCESS_FINE_LOCATION permission to scan for peripherals.
   React-Native 0.63.X started targeting Android API 29.
- Before write, read or start notification you need to call `retrieveServices` method
- Because location and bluetooth permissions are runtime permissions, you **must** request these permissions at runtime along with declaring them in your manifest.

## Example

The easiest way to test is simple make your AppRegistry point to our example component, like this:

```javascript
// in your index.ios.js or index.android.js
import React, { Component } from "react";
import { AppRegistry } from "react-native";
import App from "react-native-ble-manager/example/App"; //<-- simply point to the example js!
/* 
Note: The react-native-ble-manager/example directory is only included when cloning the repo, the above import will not work 
if trying to import react-native-ble-manager/example from node_modules
*/
AppRegistry.registerComponent("MyAwesomeApp", () => App);
```

Or, [use the example directly](example)

## Methods

### start(options)

Init the module.
Returns a `Promise` object.
Don't call this multiple times.

**Arguments**

- `options` - `JSON`

The parameter is optional the configuration keys are:

- `showAlert` - `Boolean` - [iOS only] Show or hide the alert if the bluetooth is turned off during initialization
- `restoreIdentifierKey` - `String` - [iOS only] Unique key to use for CoreBluetooth state restoration
- `queueIdentifierKey` - `String` - [iOS only] Unique key to use for a queue identifier on which CoreBluetooth events will be dispatched
- `forceLegacy` - `Boolean` - [Android only] Force to use the LegacyScanManager

**Examples**

```js
BleManager.start({ showAlert: false }).then(() => {
  // Success code
  console.log("Module initialized");
});
```

### scan(serviceUUIDs, seconds, allowDuplicates, scanningOptions)

Scan for available peripherals.
Returns a `Promise` object.

**Arguments**

- `serviceUUIDs` - `Array of String` - the UUIDs of the services to looking for. On Android the filter works only for 5.0 or newer.
- `seconds` - `Integer` - the amount of seconds to scan.
- `allowDuplicates` - `Boolean` - [iOS only] allow duplicates in device scanning
- `scanningOptions` - `JSON` - [Android only] after Android 5.0, user can control specific ble scan behaviors:
  - `numberOfMatches` - `Number` - [Android only] corresponding to [`setNumOfMatches`](<https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder.html#setNumOfMatches(int)>). Defaults to `ScanSettings.MATCH_NUM_MAX_ADVERTISEMENT`. /!\ anything other than default may only work when a `ScanFilter` is active /!\
  - `matchMode` - `Number` - [Android only] corresponding to [`setMatchMode`](<https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder.html#setMatchMode(int)>). Defaults to `ScanSettings.MATCH_MODE_AGGRESSIVE`.
  - `callbackType` - `Number` - [Android only] corresponding to [`setCallbackType`](<https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder.html#setCallbackType(int)>). Defaults `ScanSettings.CALLBACK_TYPE_ALL_MATCHES`. /!\ anything other than default may only work when a `ScanFilter` is active /!\
  - `scanMode` - `Number` - [Android only] corresponding to [`setScanMode`](<https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder.html#setScanMode(int)>). Defaults to `ScanSettings.SCAN_MODE_LOW_POWER`.
  - `reportDelay` - `Number` - [Android only] corresponding to [`setReportDelay`](<https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder.html#setReportDelay(long)>). Defaults to `0ms`.
  - `phy` - `Number` - [Android only] corresponding to [`setPhy`](https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder#setPhy(int))
  - `legacy` - `Boolean` - [Android only] corresponding to [`setLegacy`](https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder#setLegacy(boolean))
  - `exactAdvertisingName` - `string` - [Android only] corresponds to the `ScanFilter` [deviceName](https://developer.android.com/reference/android/bluetooth/le/ScanFilter.Builder#setDeviceName(java.lang.String))

**Examples**

```js
BleManager.scan([], 5, true).then(() => {
  // Success code
  console.log("Scan started");
});
```

### stopScan()

Stop the scanning.
Returns a `Promise` object.

**Examples**

```js
BleManager.stopScan().then(() => {
  // Success code
  console.log("Scan stopped");
});
```

### connect(peripheralId)

Attempts to connect to a peripheral. In many case if you can't connect you have to scan for the peripheral before.
Returns a `Promise` object.

> In iOS, attempts to connect to a peripheral do not time out (please see [Apple's doc](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/1518766-connect)), so you might need to set a timer explicitly if you don't want this behavior.

**Arguments**

- `peripheralId` - `String` - the id/mac address of the peripheral to connect.

**Examples**

```js
BleManager.connect("XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX")
  .then(() => {
    // Success code
    console.log("Connected");
  })
  .catch((error) => {
    // Failure code
    console.log(error);
  });
```

### disconnect(peripheralId, force)

Disconnect from a peripheral.
Returns a `Promise` object.

**Arguments**

- `peripheralId` - `String` - the id/mac address of the peripheral to disconnect.
- `force` - `boolean` - [Android only] defaults to true, if true force closes gatt
  connection and send the BleManagerDisconnectPeripheral
  event immediately to Javascript, else disconnects the
  connection and waits for [`disconnected state`](https://developer.android.com/reference/android/bluetooth/BluetoothProfile#STATE_DISCONNECTED) to
  [`close the gatt connection`](<https://developer.android.com/reference/android/bluetooth/BluetoothGatt#close()>)
  and then sends the BleManagerDisconnectPeripheral to the
  Javascript

**Examples**

```js
BleManager.disconnect("XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX")
  .then(() => {
    // Success code
    console.log("Disconnected");
  })
  .catch((error) => {
    // Failure code
    console.log(error);
  });
```

### enableBluetooth() [Android only]

Create the request to the user to activate the bluetooth.
Returns a `Promise` object.

**Examples**

```js
BleManager.enableBluetooth()
  .then(() => {
    // Success code
    console.log("The bluetooth is already enabled or the user confirm");
  })
  .catch((error) => {
    // Failure code
    console.log("The user refuse to enable bluetooth");
  });
```

### checkState()

Force the module to check the state of the native BLE manager and trigger a BleManagerDidUpdateState event.
Resolves to a promise containing the current BleState.

**Examples**

```js
BleManager.checkState().then(state => console.log(`current BLE state = '${state}'.`));
```

### startNotification(peripheralId, serviceUUID, characteristicUUID)

Start the notification on the specified characteristic, you need to call `retrieveServices` method before.
Returns a `Promise` object.

**Arguments**

- `peripheralId` - `String` - the id/mac address of the peripheral.
- `serviceUUID` - `String` - the UUID of the service.
- `characteristicUUID` - `String` - the UUID of the characteristic.

**Examples**

```js
BleManager.startNotification(
  "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
  "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
  "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
)
  .then(() => {
    // Success code
    console.log("Notification started");
  })
  .catch((error) => {
    // Failure code
    console.log(error);
  });
```

### startNotificationUseBuffer(peripheralId, serviceUUID, characteristicUUID, buffer) [Android only]

Start the notification on the specified characteristic, you need to call `retrieveServices` method before. The buffer will collect a number or messages from the server and then emit once the buffer count it reached. Helpful to reducing the number or js bridge crossings when a characteristic is sending a lot of messages.
Returns a `Promise` object.

**Arguments**

- `peripheralId` - `String` - the id/mac address of the peripheral.
- `serviceUUID` - `String` - the UUID of the service.
- `characteristicUUID` - `String` - the UUID of the characteristic.
- `buffer` - `Integer` - a number of message to buffer prior to emit for the characteristic.

**Examples**

```js
BleManager.startNotification(
  "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
  "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
  "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
  1234
)
  .then(() => {
    // Success code
    console.log("Notification started");
  })
  .catch((error) => {
    // Failure code
    console.log(error);
  });
```

### stopNotification(peripheralId, serviceUUID, characteristicUUID)

Stop the notification on the specified characteristic.
Returns a `Promise` object.

**Arguments**

- `peripheralId` - `String` - the id/mac address of the peripheral.
- `serviceUUID` - `String` - the UUID of the service.
- `characteristicUUID` - `String` - the UUID of the characteristic.

### read(peripheralId, serviceUUID, characteristicUUID)

Read the current value of the specified characteristic, you need to call `retrieveServices` method before.
Returns a `Promise` object that will resolves to an array of plain integers (`number[]`) representing a `ByteArray` structure.
That array can then be converted to a JS `ArrayBuffer` for example using `Buffer.from()` [thanks to this buffer module](https://github.com/feross/buffer).

**Arguments**

- `peripheralId` - `String` - the id/mac address of the peripheral.
- `serviceUUID` - `String` - the UUID of the service.
- `characteristicUUID` - `String` - the UUID of the characteristic.

**Examples**

```js
BleManager.read(
  "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
  "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
  "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
)
  .then((readData) => {
    // Success code
    console.log("Read: " + readData);

    // https://github.com/feross/buffer
    // https://nodejs.org/api/buffer.html#static-method-bufferfromarray
    const buffer = Buffer.from(readData); 
    const sensorData = buffer.readUInt8(1, true);
  })
  .catch((error) => {
    // Failure code
    console.log(error);
  });
```

### write(peripheralId, serviceUUID, characteristicUUID, data, maxByteSize)

Write with response to the specified characteristic, you need to call `retrieveServices` method before.
Returns a `Promise` object.

**Arguments**

- `peripheralId` - `String` - the id/mac address of the peripheral.
- `serviceUUID` - `String` - the UUID of the service.
- `characteristicUUID` - `String` - the UUID of the characteristic.
- `data` - `number[]` - the data to write as a plain integer array representing a `ByteArray` structure.
- `maxByteSize` - `Integer` - specify the max byte size before splitting message, defaults to 20 bytes if not specified

**Data preparation**

To convert your data to a `number[]`, you should probably be manipulating a `Buffer` or anything representing a JS `ArrayBuffer`.
This will make sure you are converting from valid byte representations of your data first and not with [an integer outside the expected range](https://techtutorialsx.com/2019/10/27/node-js-converting-array-to-buffer/).

You can create a buffer from files, numbers or strings easily (see examples bellow).

```js
// https://github.com/feross/buffer
import { Buffer } from 'buffer';

 * // Creates a Buffer containing the bytes [0x01, 0x02, 0x03].
 * const buffer = Buffer.from([1, 2, 3]);
 *
 * // Creates a Buffer containing the bytes [0x01, 0x01, 0x01, 0x01] – the entries
 * // are all truncated using `(value & 255)` to fit into the range 0–255.
 * const buffer = Buffer.from([257, 257.5, -255, '1']);
 *
 * // Creates a Buffer containing the UTF-8-encoded bytes for the string 'tést':
 * // [0x74, 0xc3, 0xa9, 0x73, 0x74] (in hexadecimal notation)
 * // [116, 195, 169, 115, 116] (in decimal notation)
 * const buffer = Buffer.from('tést');
```

Feel free to use other packages or google how to convert into byte array if your data has other format.

**Examples**

```js
BleManager.write(
  "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
  "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
  "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
  // encode & extract raw `number[]`.
  // Each number should be in the 0-255 range as it is converted from a valid byte.
  buffer.toJSON().data
)
  .then(() => {
    // Success code
    console.log("Write: " + data);
  })
  .catch((error) => {
    // Failure code
    console.log(error);
  });
```

### writeWithoutResponse(peripheralId, serviceUUID, characteristicUUID, data, maxByteSize, queueSleepTime)

Write without response to the specified characteristic, you need to call `retrieveServices` method before.
Returns a `Promise` object.

**Arguments**

- `peripheralId` - `String` - the id/mac address of the peripheral.
- `serviceUUID` - `String` - the UUID of the service.
- `characteristicUUID` - `String` - the UUID of the characteristic.
- `data` - `number[]` - the data to write as a plain integer array representing a `ByteArray` structure. (see `write()`).
- `maxByteSize` - `Integer` - (Optional) specify the max byte size
- `queueSleepTime` - `Integer` - (Optional) specify the wait time before each write if the data is greater than maxByteSize

**Data preparation**

If your data is not in `number[]` format check info fom the `write()` function example above.

**Example**

```js
BleManager.writeWithoutResponse(
  "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
  "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
  "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
  data
)
  .then(() => {
    // Success code
    console.log("Writed: " + data);
  })
  .catch((error) => {
    // Failure code
    console.log(error);
  });
```

### readRSSI(peripheralId)

Read the current value of the RSSI.
Returns a `Promise` object resolving with the updated RSSI value (`number`) if it succeeds.

**Arguments**

- `peripheralId` - `String` - the id/mac address of the peripheral.

**Examples**

```js
BleManager.readRSSI("XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX")
  .then((rssi) => {
    // Success code
    console.log("Current RSSI: " + rssi);
  })
  .catch((error) => {
    // Failure code
    console.log(error);
  });
```

### requestConnectionPriority(peripheralId, connectionPriority) [Android only API 21+]

Request a connection parameter update.
Returns a `Promise` object which fulfills with the status of the request.

**Arguments**

- `peripheralId` - `String` - the id/mac address of the peripheral.
- `connectionPriority` - `Integer` - the connection priority to be requested, as follows:
  - 0 - balanced priority connection
  - 1 - high priority connection
  - 2 - low power priority connection

**Examples**

```js
BleManager.requestConnectionPriority("XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX", 1)
  .then((status) => {
    // Success code
    console.log("Requested connection priority");
  })
  .catch((error) => {
    // Failure code
    console.log(error);
  });
```

### requestMTU(peripheralId, mtu) [Android only API 21+]

Request an MTU size used for a given connection.
Returns a `Promise` object.

**Arguments**

- `peripheralId` - `String` - the id/mac address of the peripheral.
- `mtu` - `Integer` - the MTU size to be requested in bytes.

**Examples**

```js
BleManager.requestMTU("XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX", 512)
  .then((mtu) => {
    // Success code
    console.log("MTU size changed to " + mtu + " bytes");
  })
  .catch((error) => {
    // Failure code
    console.log(error);
  });
```

### retrieveServices(peripheralId[, serviceUUIDs])

Retrieve the peripheral's services and characteristics.
Returns a `Promise` object.

**Arguments**

- `peripheralId` - `String` - the id/mac address of the peripheral.
- `serviceUUIDs` - `String[]` - [iOS only] only retrieve these services.

**Examples**

```js
BleManager.retrieveServices("XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX").then(
  (peripheralInfo) => {
    // Success code
    console.log("Peripheral info:", peripheralInfo);
  }
);
```

### refreshCache(peripheralId) [Android only]

refreshes the peripheral's services and characteristics cache
Returns a `Promise` object.

**Arguments**

- `peripheralId` - `String` - the id/mac address of the peripheral.

**Examples**

```js
BleManager.refreshCache("XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX")
  .then((peripheralInfo) => {
    // Success code
    console.log("cache refreshed!");
  })
  .catch((error) => {
    console.error(error);
  });
```

### getConnectedPeripherals(serviceUUIDs)

Return the connected peripherals.
Returns a `Promise` object.

**Arguments**

- `serviceUUIDs` - `Array of String` - the UUIDs of the services to looking for.

**Examples**

```js
BleManager.getConnectedPeripherals([]).then((peripheralsArray) => {
  // Success code
  console.log("Connected peripherals: " + peripheralsArray.length);
});
```

### createBond(peripheralId,peripheralPin) [Android only]

Start the bonding (pairing) process with the remote device. If you pass peripheralPin(optional), bonding will be auto(without manual entering pin)
Returns a `Promise` object that will resolves if the bond is successfully created, otherwise it will be rejected with the appropriate error message.

**Examples**

```js
BleManager.createBond(peripheralId)
  .then(() => {
    console.log("createBond success or there is already an existing one");
  })
  .catch(() => {
    console.log("fail to bond");
  });
```

### removeBond(peripheralId) [Android only]

Remove a paired device.
Returns a `Promise` object.

**Examples**

```js
BleManager.removeBond(peripheralId)
  .then(() => {
    console.log("removeBond success");
  })
  .catch(() => {
    console.log("fail to remove the bond");
  });
```

### getBondedPeripherals() [Android only]

Return the bonded peripherals.
Returns a `Promise` object.

**Examples**

```js
BleManager.getBondedPeripherals([]).then((bondedPeripheralsArray) => {
  // Each peripheral in returned array will have id and name properties
  console.log("Bonded peripherals: " + bondedPeripheralsArray.length);
});
```

### getDiscoveredPeripherals()

Return the discovered peripherals after a scan.
Returns a `Promise` object.

**Examples**

```js
BleManager.getDiscoveredPeripherals([]).then((peripheralsArray) => {
  // Success code
  console.log("Discovered peripherals: " + peripheralsArray.length);
});
```

### removePeripheral(peripheralId) [Android only]

Removes a disconnected peripheral from the cached list.
It is useful if the device is turned off, because it will be re-discovered upon turning on again.
Returns a `Promise` object.

**Arguments**

- `peripheralId` - `String` - the id/mac address of the peripheral.

### isPeripheralConnected(peripheralId, serviceUUIDs)

Check whether a specific peripheral is connected and return `true` or `false`.
Returns a `Promise` object.

**Examples**

```js
BleManager.isPeripheralConnected(
  "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
  []
).then((isConnected) => {
  if (isConnected) {
    console.log("Peripheral is connected!");
  } else {
    console.log("Peripheral is NOT connected!");
  }
});
```

### setName(name) [Android only]

Create the request to set the name of the bluetooth adapter. (https://developer.android.com/reference/android/bluetooth/BluetoothAdapter#setName(java.lang.String))
Returns a `Promise` object.

**Examples**

```js
BleManager.setName("INNOVEIT_CENTRAL")
  .then(() => {
    // Success code
    console.log("Name set successfully");
  })
  .catch((error) => {
    // Failure code
    console.log("Name could not be set");
  });
```

## Events

### BleManagerStopScan

The scanning for peripherals is ended.

**Arguments**

- `status` - `Number` - [iOS] the reason for stopping the scan. Error code 10 is used for timeouts, 0 covers everything else. [Android] the reason for stopping the scan (<https://developer.android.com/reference/android/bluetooth/le/ScanCallback#constants_1>). Error code 10 is used for timeouts

**Examples**

```js
bleManagerEmitter.addListener("BleManagerStopScan", (args) => {
  // Scanning is stopped
});
```

### BleManagerDidUpdateState

The BLE change state.

**Arguments**

- `state` - `String` - the new BLE state. can be one of `unknown` (iOS only), `resetting` (iOS only), `unsupported`, `unauthorized` (iOS only), `on`, `off`, `turning_on` (android only), `turning_off` (android only).

**Examples**

```js
bleManagerEmitter.addListener("BleManagerDidUpdateState", (args) => {
  // The new state: args.state
});
```

### BleManagerDiscoverPeripheral

The scanning find a new peripheral.

**Arguments**

- `id` - `String` - the id of the peripheral
- `name` - `String` - the name of the peripheral
- `rssi` - `Number` - the RSSI value
- `advertising` - `JSON` - the advertising payload, here are some examples:
  - `isConnectable` - `Boolean`
  - `serviceUUIDs` - `Array of String`
  - `manufacturerData` - `JSON` - contains the raw `bytes` and `data` (Base64 encoded string)
  - `serviceData` - `JSON` - contains the raw `bytes` and `data` (Base64 encoded string)
  - `txPowerLevel` - `Int`

**Examples**

```js
bleManagerEmitter.addListener("BleManagerDiscoverPeripheral", (args) => {
  // The id: args.id
  // The name: args.name
});
```

### BleManagerDidUpdateValueForCharacteristic

A characteristic notify a new value.

**Arguments**

- `value` — `Array` — the read value
- `peripheral` — `String` — the id of the peripheral
- `characteristic` — `String` — the UUID of the characteristic
- `service` — `String` — the UUID of the characteristic

> Event will only be emitted after successful `startNotification`.

**Example**

```js
import { bytesToString } from "convert-string";
import { NativeModules, NativeEventEmitter } from "react-native";

const BleManagerModule = NativeModules.BleManager;
const bleManagerEmitter = new NativeEventEmitter(BleManagerModule);

async function connectAndPrepare(peripheral, service, characteristic) {
  // Connect to device
  await BleManager.connect(peripheral);
  // Before startNotification you need to call retrieveServices
  await BleManager.retrieveServices(peripheral);
  // To enable BleManagerDidUpdateValueForCharacteristic listener
  await BleManager.startNotification(peripheral, service, characteristic);
  // Add event listener
  bleManagerEmitter.addListener(
    "BleManagerDidUpdateValueForCharacteristic",
    ({ value, peripheral, characteristic, service }) => {
      // Convert bytes array to string
      const data = bytesToString(value);
      console.log(`Received ${data} for characteristic ${characteristic}`);
    }
  );
  // Actions triggereng BleManagerDidUpdateValueForCharacteristic event
}
```

### BleManagerConnectPeripheral

A peripheral was connected.

**Arguments**

- `peripheral` - `String` - the id of the peripheral
- `status` - `Number` - [Android only] connect [`reasons`](<https://developer.android.com/reference/android/bluetooth/BluetoothGattCallback.html#onConnectionStateChange(android.bluetooth.BluetoothGatt,%20int,%20int)>)

### BleManagerDisconnectPeripheral

A peripheral was disconnected.

**Arguments**

- `peripheral` - `String` - the id of the peripheral
- `status` - `Number` - [Android only] disconnect [`reasons`](<https://developer.android.com/reference/android/bluetooth/BluetoothGattCallback.html#onConnectionStateChange(android.bluetooth.BluetoothGatt,%20int,%20int)>)
- `domain` - `String` - [iOS only] disconnect error domain
- `code` - `Number` - [iOS only] disconnect error code (<https://developer.apple.com/documentation/corebluetooth/cberror/code>)

### BleManagerPeripheralDidBond

A bond with a peripheral was established

**Arguments**

Object with information about the device

### BleManagerCentralManagerWillRestoreState [iOS only]

This is fired when [`centralManager:WillRestoreState:`](https://developer.apple.com/documentation/corebluetooth/cbcentralmanagerdelegate/1518819-centralmanager) is called (app relaunched in the background to handle a bluetooth event).

**Arguments**

- `peripherals` - `Array` - an array of previously connected peripherals.

_For more on performing long-term bluetooth actions in the background:_

[iOS Bluetooth State Preservation and Restoration](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html#//apple_ref/doc/uid/TP40013257-CH7-SW10)

[iOS Relaunch Conditions](https://developer.apple.com/library/archive/qa/qa1962/_index.html)

### BleManagerDidUpdateNotificationStateFor [iOS only]

The peripheral received a request to start or stop providing notifications for a specified characteristic's value.

**Arguments**

- `peripheral` - `String` - the id of the peripheral
- `characteristic` - `String` - the UUID of the characteristic
- `isNotifying` - `Boolean` - Is the characteristic notifying or not
- `domain` - `String` - [iOS only] error domain
- `code` - `Number` - [iOS only] error code

## Library development

- the library is written in typescript and needs to be built before being used for publication or local development, using the provided npm scripts in `package.json`.
- the local `example` project is configured to work with the locally built version of the library. To be able to run it, you need to build at least once the library so that its outputs listed as entrypoint in `package.json` (in the `dist` folder) are properly generated for consumption by the example project:

from the root folder:

```shell
npm install
npm run build
```

> if you are modifying the typescript files of the library (in `src/`) on the fly, you can run `npm run watch` instead. If you are modifying files from the native counterparts, you'll need to rebuild the whole app for your target environnement (`npm run android/ios`).
