---
layout: page
title: Events
permalink: /events/
nav_order: 2
parent: Usage
---

# Events

Since react-native version 0.76, events are handled with specific methods that return the listener.

**Examples**

```js
useEffect(() => {
  const onStopListener = BleManager.onStopScan((args) => {
    // Scanning is stopped args.status
  });

  return () => {
    onStopListener.remove();
  };
    
}, []);
```
---

### onStopScan

The scanning for peripherals is ended.

**Arguments**

- `status` - `Number` - [iOS] the reason for stopping the scan. Error code 10 is used for timeouts, 0 covers everything else. [Android] the reason for stopping the scan (<https://developer.android.com/reference/android/bluetooth/le/ScanCallback#constants_1>). Error code 10 is used for timeouts


---

### onDidUpdateState

The BLE change state.

**Arguments**

- `state` - `String` - the new BLE state. can be one of `unknown` (iOS only), `resetting` (iOS only), `unsupported`, `unauthorized` (iOS only), `on`, `off`, `turning_on` (android only), `turning_off` (android only).


---

### onDiscoverPeripheral

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

---

### onDidUpdateValueForCharacteristic

A characteristic notify a new value.

**Arguments**

- `value` — `Array` — the read value
- `peripheral` — `String` — the id of the peripheral
- `characteristic` — `String` — the UUID of the characteristic
- `service` — `String` — the UUID of the characteristic

> Event will only be emitted after successful `startNotification`.

---

### onConnectPeripheral

A peripheral was connected.

**Arguments**

- `peripheral` - `String` - the id of the peripheral
- `status` - `Number` - [Android only] connect [`reasons`](<https://developer.android.com/reference/android/bluetooth/BluetoothGattCallback.html#onConnectionStateChange(android.bluetooth.BluetoothGatt,%20int,%20int)>)

---

### onDisconnectPeripheral

A peripheral was disconnected.

**Arguments**

- `peripheral` - `String` - the id of the peripheral
- `status` - `Number` - [Android only] disconnect [`reasons`](<https://developer.android.com/reference/android/bluetooth/BluetoothGattCallback.html#onConnectionStateChange(android.bluetooth.BluetoothGatt,%20int,%20int)>)
- `domain` - `String` - [iOS only] disconnect error domain
- `code` - `Number` - [iOS only] disconnect error code (<https://developer.apple.com/documentation/corebluetooth/cberror/code>)

---

### onPeripheralDidBond

A bond with a peripheral was established

**Arguments**

Object with information about the device

---

### onCentralManagerWillRestoreState [iOS only]

This is fired when [`centralManager:WillRestoreState:`](https://developer.apple.com/documentation/corebluetooth/cbcentralmanagerdelegate/1518819-centralmanager) is called (app relaunched in the background to handle a bluetooth event).

**Arguments**

- `peripherals` - `Array` - an array of previously connected peripherals.

_For more on performing long-term bluetooth actions in the background:_

[iOS Bluetooth State Preservation and Restoration](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html#//apple_ref/doc/uid/TP40013257-CH7-SW10)

[iOS Relaunch Conditions](https://developer.apple.com/documentation/technotes/tn3115-bluetooth-state-restoration-app-relaunch-rules/)

---
### onDidUpdateNotificationStateFor [iOS only]

The peripheral received a request to start or stop providing notifications for a specified characteristic's value.

**Arguments**

- `peripheral` - `String` - the id of the peripheral
- `characteristic` - `String` - the UUID of the characteristic
- `isNotifying` - `Boolean` - Is the characteristic notifying or not
- `domain` - `String` - [iOS only] error domain
- `code` - `Number` - [iOS only] error code

---

### onCompanionPeripheral [Android only]

User picked a device to associate with.

Null if the request was cancelled by the user.

**Arguments**

- `id` - `String` - the id of the peripheral
- `name` - `String` - the name of the peripheral
- `rssi` - `Number` - the RSSI value

---

### onCompanionFailure [Android only]

Associate callback received a failure or failed to start the intent to
pick the device to associate.