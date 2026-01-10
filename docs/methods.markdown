---
layout: page
title: Methods
permalink: /methods/
nav_order: 1
parent: Usage
---

<details markdown="block">
  <summary>
    Table of contents
  </summary>
  {: .text-delta }
1. TOC
{:toc}
</details>

# Methods
{: .no_toc }

## Common (iOS & Android)

These APIs are available on both platforms.

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

---

### isStarted()

Returns if the module was initialised with `start`.

**Examples**

```js
BleManager.isStarted().then((started) => {
  // Success code
  console.log(`Module is ${isStarted ? '' : 'not '}started`);
});
```

---

### scan(scanningOptions)

Scan for available peripherals.

See `onDiscoverPeripheral` to get live updates of devices being discovered.

See `getDiscoveredPeripherals` to get a list of discovered devices after a scan is completed.

Returns a `Promise` object.

**Arguments**
- `scanningOptions` - `JSON` - user can control specific ble scan behaviors:
  - `serviceUUIDs` - `String[]` - the UUIDs of the services to look for.
  - `seconds` - `Integer` - the amount of seconds to scan. If not set or set to `0`, scans until `stopScan()` is called.
  - `exactAdvertisingName` - `String[]` - In Android corresponds to the `ScanFilter` [deviceName](<https://developer.android.com/reference/android/bluetooth/le/ScanFilter.Builder#setDeviceName(java.lang.String)>). In iOS the filter is done manually before sending the peripheral.
  - `allowDuplicates` - `Boolean` - [iOS only] allow duplicates in device scanning
  - `numberOfMatches` - `Number` - [Android only] corresponding to [`setNumOfMatches`](<https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder.html#setNumOfMatches(int)>). Defaults to `ScanSettings.MATCH_NUM_MAX_ADVERTISEMENT`. /!\ anything other than default may only work when a `ScanFilter` is active /!\
  - `matchMode` - `Number` - [Android only] corresponding to [`setMatchMode`](<https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder.html#setMatchMode(int)>). Defaults to `ScanSettings.MATCH_MODE_AGGRESSIVE`.
  - `callbackType` - `Number` - [Android only] corresponding to [`setCallbackType`](<https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder.html#setCallbackType(int)>). Defaults `ScanSettings.CALLBACK_TYPE_ALL_MATCHES`. /!\ anything other than default may only work when a `ScanFilter` is active /!\
  - `scanMode` - `Number` - [Android only] corresponding to [`setScanMode`](<https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder.html#setScanMode(int)>). Defaults to `ScanSettings.SCAN_MODE_LOW_POWER`.
  - `reportDelay` - `Number` - [Android only] corresponding to [`setReportDelay`](<https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder.html#setReportDelay(long)>). Defaults to `0ms`.
  - `phy` - `Number` - [Android only] corresponding to [`setPhy`](<https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder#setPhy(int)>)
  - `legacy` - `Boolean` - [Android only] corresponding to [`setLegacy`](<https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder#setLegacy(boolean)>)
  - `manufacturerData` - `Object` - [Android only] corresponding to [`setManufacturerData`](<https://developer.android.com/reference/android/bluetooth/le/ScanFilter.Builder#setManufacturerData(int,%20byte[],%20byte[])>). Filter by manufacturer id or data.
    - `manufacturerId` - `Number` - Manufacturer / company id to filter for.
    - `manufacturerData` - `Number[]` - Additional manufacturer data filter.
    - `manufacturerDataMask` - `Number[]` - Mask for manufacturer data, must have the same length as `manufacturerData`.
      For any bit in the mask, set it to 1 if it needs to match the one in manufacturer data, otherwise set it to 0.
  - `useScanIntent` - `Boolean` - [Android only, API 26+] deliver scan results through a `PendingIntent` instead of the default callback. Any ongoing callback scan is automatically stopped before switching to this mode.

**Examples**

```js
BleManager.scan({ serviceUUIDs: [], seconds: 5 }).then(() => {
  // Success code
  console.log("Scan started");
});
```

---

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

---

### connect(peripheralId, options)

Attempts to connect to a peripheral. In many case if you can't connect you have to scan for the peripheral before.
Returns a `Promise` object.

> In iOS, attempts to connect to a peripheral do not time out (please see [Apple's doc](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/1518766-connect)), so you might need to set a timer explicitly if you don't want this behavior.

**Arguments**

- `peripheralId` - `String` - the id/mac address of the peripheral to connect.
- `options` - `JSON` - The parameter is optional the configuration keys are:

  - `phy` - `Number` - [Android only] corresponding to the preferred phy channel ([`Android doc`](<https://developer.android.com/reference/android/bluetooth/BluetoothDevice?hl=en#connectGatt(android.content.Context,%20boolean,%20android.bluetooth.BluetoothGattCallback,%20int,%20int)>))
  - `autoconnect` - `Boolean` - [Android only] whether to directly connect to the remote device (false) or to automatically connect as soon as the remote device becomes available (true) ([`Android doc`](<https://developer.android.com/reference/android/bluetooth/BluetoothDevice?hl=en#connectGatt(android.content.Context,%20boolean,%20android.bluetooth.BluetoothGattCallback,%20int,%20int)>))

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

---

### disconnect(peripheralId, force)

Disconnect from a peripheral.
Returns a `Promise` object.

**Arguments**

- `peripheralId` - `String` - the id/mac address of the peripheral to disconnect.
- `force` - `boolean` - [Android only] defaults to true. If true force closes gatt
  connection and send the event to `onDisconnectPeripheral`
  immediately, else disconnects the
  connection and waits for [`disconnected state`](https://developer.android.com/reference/android/bluetooth/BluetoothProfile#STATE_DISCONNECTED) to
  [`close the gatt connection`](<https://developer.android.com/reference/android/bluetooth/BluetoothGatt#close()>)
  and then sends the event to `onDisconnectPeripheral`

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

---

### checkState()

Force the module to check the state of the native BLE manager and trigger a BleManagerDidUpdateState event.
Resolves to a promise containing the current BleState.

**Examples**

```js
BleManager.checkState().then((state) =>
  console.log(`current BLE state = '${state}'.`)
);
```

---

### startNotification(peripheralId, serviceUUID, characteristicUUID)

Start the notification on the specified characteristic, you need to call `retrieveServices` method before.

Events will be send to `onDidUpdateValueForCharacteristic` when the peripheral notifies a new value for the characteristic. 

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

---

### stopNotification(peripheralId, serviceUUID, characteristicUUID)

Stop the notification on the specified characteristic.
Returns a `Promise` object.

**Arguments**

- `peripheralId` - `String` - the id/mac address of the peripheral.
- `serviceUUID` - `String` - the UUID of the service.
- `characteristicUUID` - `String` - the UUID of the characteristic.

---

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

---

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

// Creates a Buffer containing the bytes [0x01, 0x02, 0x03].
const buffer = Buffer.from([1, 2, 3]);

// Creates a Buffer containing the bytes [0x01, 0x01, 0x01, 0x01] – the entries
// are all truncated using `(value & 255)` to fit into the range 0–255.
const buffer = Buffer.from([257, 257.5, -255, '1']);

// Creates a Buffer containing the UTF-8-encoded bytes for the string 'tést':
// [0x74, 0xc3, 0xa9, 0x73, 0x74] (in hexadecimal notation)
// [116, 195, 169, 115, 116] (in decimal notation)
const buffer = Buffer.from('tést');
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

---

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
    console.log("Wrote: " + data);
  })
  .catch((error) => {
    // Failure code
    console.log(error);
  });
```

---

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

---

### readDescriptor(peripheralId, serviceId, characteristicId, descriptorId)

Read the current value of the specified descriptor, you need to call `retrieveServices` method before.
Returns a `Promise` object that will resolves to an array of plain integers (`number[]`) representing a `ByteArray` structure.
That array can then be converted to a JS `ArrayBuffer` for example using `Buffer.from()` [thanks to this buffer module](https://github.com/feross/buffer).

**Arguments**

- `peripheralId` - `String` - the id/mac address of the peripheral.
- `serviceUUID` - `String` - the UUID of the service.
- `characteristicUUID` - `String` - the UUID of the characteristic.
- `descriptorUUID` - `String` - the UUID of the descriptor.

**Examples**

```js
BleManager.readDescriptor(
  "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
  "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
  "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
  "XXXX"
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

---

### writeDescriptor(peripheralId, serviceId, characteristicId, descriptorId, data)

Write a value to the specified descriptor, you need to call `retrieveServices` method before.
Returns a `Promise` object.

**Arguments**

- `peripheralId` - `String` - the id/mac address of the peripheral.
- `serviceUUID` - `String` - the UUID of the service.
- `characteristicUUID` - `String` - the UUID of the characteristic.
- `descriptorUUID` - `String` - the UUID of the descriptor.
- `data` - `number[]` - the data to write as a plain integer array representing a `ByteArray` structure.

**Examples**

```js
BleManager.writeDescriptor(
  "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
  "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
  "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
  "XXXX",
  [1, 2]
)
  .then(() => {
    // Success code
  })
  .catch((error) => {
    // Failure code
    console.log(error);
  });
```

---

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

---

### getConnectedPeripherals(serviceUUIDs)

Return the connected peripherals.
Returns a `Promise` object.
> In Android, Peripherals "advertising" property can be not set!
> Will be available if peripheral was found through scan before connect. This matches to current Android Bluetooth design specification.

**Arguments**

- `serviceUUIDs` - `String[]` - [iOS only] Optional, only retrieve peripherals with these services. Ignored in Android.

**Examples**

```js
BleManager.getConnectedPeripherals([]).then((peripheralsArray) => {
  // Success code
  console.log("Connected peripherals: " + peripheralsArray.length);
});
```

---

### getDiscoveredPeripherals()

Return the discovered peripherals after a scan.
Returns a `Promise` object.

**Examples**

```js
BleManager.getDiscoveredPeripherals().then((peripheralsArray) => {
  // Success code
  console.log("Discovered peripherals: " + peripheralsArray.length);
});
```

---

### isPeripheralConnected(peripheralId, serviceUUIDs)

Check whether a specific peripheral is connected and return `true` or `false`.
Returns a `Promise` object.

**Arguments**

- `peripheralId` - `String` - The id/mac address of the peripheral.
- `serviceUUIDs` - `String[]` - [iOS only] Optional, only retrieve peripherals with these services. Ignored in Android.

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

---

### isScanning()

Checks whether the scan is in progress and return `true` or `false`.
Returns a `Promise` object.

**Examples**

```js
BleManager.isScanning().then((isScanning) => {
  if (isScanning) {
    console.log("Is scanning!");
  } else {
    console.log("Is NOT scanning!");
  }
});
```

---

## Android-only

APIs that require Android; many expose platform concepts like ScanSettings, bonding, or adapter state.

### companionScan() [Android only, API 26+]

Scan for companion devices.

Rejects if the companion device manager is not supported on this device.

The promise it will eventually resolve with either:

1.  peripheral if user selects one
2.  null if user "cancels" (i.e. doesn't select anything)

See `BleManager.supportsCompanion`.

See: https://developer.android.com/develop/connectivity/bluetooth/companion-device-pairing

**Arguments**

- `serviceUUIDs` - `String[]` - List of service UUIDs to use as a filter
- `options` - `JSON` - Additional options

  - `single` - `String?` - Scan only for single peripheral. See Android's `AssociationRequest.Builder.setSingleDevice`.

**Examples**

```js
BleManager.companionScan([]).then(peripheral => {
  console.log('Associated peripheral', peripheral);
});
```

---

### enableBluetooth() [Android only]

Create the ACTION_REQUEST_ENABLE to ask the user to activate the bluetooth.
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

---

### supportsCompanion() [Android only]

Check if current device supports the companion device manager.

**Examples**

```js
BleManager.supportsCompanion().then((isSupported) => {
  if (isSupported) {
    console.log("Companion device manager is supported!");
  } else {
    console.log("Companion device manager is NOT supported!");
  }
});
```

---

### startNotificationWithBuffer(peripheralId, serviceUUID, characteristicUUID, buffer) [Android only]

Start the notification on the specified characteristic, you need to call `retrieveServices` method before. The buffer collect messages until the buffer of messages bytes reaches the limit defined with the `buffer` argument and then emit all the collected data. Useful to reduce the number of calls between the native and the react-native part in case of many messages.
Returns a `Promise` object.

**Arguments**

- `peripheralId` - `String` - the id/mac address of the peripheral.
- `serviceUUID` - `String` - the UUID of the service.
- `characteristicUUID` - `String` - the UUID of the characteristic.
- `buffer` - `Integer` - the capacity of the buffer (bytes) stored before emitting the data for the characteristic.

**Examples**

```js
BleManager.startNotificationWithBuffer(
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

---

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

---

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

---

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

---

### getAssociatedPeripherals() [Android only, API 26+]

Retrieve associated peripherals (from companion manager).

---

### removeAssociatedPeripheral(peripheralId) [Android only, API 26+]

Remove an associated peripheral.

Rejects if no association is found.

**Arguments**

- `peripheralId` - `String` - Peripheral to remove

---

### createBond(peripheralId,peripheralPin) [Android only]

Start the bonding (pairing) process with the remote device. If you pass peripheralPin (optional), bonding will be auto (without manually entering the pin).
Returns a `Promise` object that will resolve if the bond is successfully created, otherwise it will be rejected with the appropriate error message.
> In Android, Ensure to make one bond request at a time.

**Arguments**

- `peripheralId` - `String` - The id/mac address of the peripheral.
- `peripheralPin` - `String` - Optional, will be used to auto-bond if possible.

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

---

### removeBond(peripheralId) [Android only]

Remove a paired device.
Returns a `Promise` object.

**Arguments**

- `peripheralId` - `String` - The id/mac address of the peripheral.

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

---

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

---

### removePeripheral(peripheralId) [Android only]

Removes a disconnected peripheral from the cached list.
It is useful if the device is turned off, because it will be re-discovered upon turning on again.
Returns a `Promise` object.

**Arguments**

- `peripheralId` - `String` - the id/mac address of the peripheral.

---

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

---

## iOS-only

APIs that surface CoreBluetooth limitations or platform-specific helpers.

### getMaximumWriteValueLengthForWithoutResponse(peripheralId) [iOS only]

Return the maximum value length for WriteWithoutResponse.
Returns a `Promise` object.

**Examples**

```js
BleManager.getMaximumWriteValueLengthForWithoutResponse(
  "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
).then((maxValue) => {
  console.log("Maximum length for WriteWithoutResponse: " + maxValue);
});
```

---

### getMaximumWriteValueLengthForWithResponse(peripheralId) [iOS only]

Return the maximum value length for WriteWithResponse.
Returns a `Promise` object.

**Examples**

```js
BleManager.getMaximumWriteValueLengthForWithResponse(
  "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
).then((maxValue) => {
  console.log("Maximum length for WriteWithResponse: " + maxValue);
});
```
