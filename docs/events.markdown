---
layout: page
title: Events
permalink: /events/
nav_order: 2
parent: Usage
---

# Events

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
  - `manufacturerData` - `JSON` - contains a json with the company id as field and the custom value as raw `bytes` and `data` (Base64 encoded string)
  - `serviceData` - `JSON` - contains the raw `bytes` and `data` (Base64 encoded string)
  - `txPowerLevel` - `Int`
  - `rawData` - [Android only] `JSON` - contains the raw `bytes` and `data` (Base64 encoded string) of the all advertising data

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
