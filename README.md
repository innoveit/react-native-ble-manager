# react-native-ble-manager
[![npm version](https://img.shields.io/npm/v/react-native-ble-manager.svg?style=flat)](https://www.npmjs.com/package/react-native-ble-manager)
[![npm downloads](https://img.shields.io/npm/dm/react-native-ble-manager.svg?style=flat)](https://www.npmjs.com/package/react-native-ble-manager)
[![GitHub issues](https://img.shields.io/github/issues/innoveit/react-native-ble-manager.svg?style=flat)](https://github.com/innoveit/react-native-ble-manager/issues)

This is a porting of https://github.com/don/cordova-plugin-ble-central project to React Native.

## Requirements
RN 0.40+

RN 0.30-0.39 supported until 2.4.3

## Supported Platforms
- iOS 8+
- Android (API 19+)

## Install
```shell
npm i --save react-native-ble-manager
```
After installing, you need to link the native library. You can either:
* Link native library with `react-native link`, or
* Link native library manually

Both approaches are described below.

### Link Native Library with `react-native link`

```shell
react-native link react-native-ble-manager
```

After this step:
 * iOS should be linked properly.
 * Android will need one more step, you need to edit `android/app/build.gradle`:
```gradle
// file: android/app/build.gradle
...

android {
    ...

    defaultConfig {
        ...
        minSdkVersion 19 // <--- make sure this is 19 or greater
        ...
    }
    ...
}
```

### Link Native Library Manually

#### iOS
- Open the node_modules/react-native-ble-manager/ios folder and drag BleManager.xcodeproj into your Libraries group.
- Check the "Build Phases"of your project and add "libBleManager.a" in the "Link Binary With Libraries" section.

#### Android
##### Update Gradle Settings

```gradle
// file: android/settings.gradle
...

include ':react-native-ble-manager'
project(':react-native-ble-manager').projectDir = new File(rootProject.projectDir, '../node_modules/react-native-ble-manager/android')
```
##### Update Gradle Build

```gradle
// file: android/app/build.gradle
...

android {
    ...

    defaultConfig {
        ...
        minSdkVersion 19 // <--- make sure this is 19 or greater
        ...
    }
    ...
}

dependencies {
    ...
    compile project(':react-native-ble-manager')
}
```
##### Update Android Manifest

```xml
// file: android/app/src/main/AndroidManifest.xml
...
    <uses-permission android:name="android.permission.BLUETOOTH"/>
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
...
```

##### Register React Package
```java
...
import it.innove.BleManagerPackage; // <--- import

public class MainApplication extends Application implements ReactApplication {

    ...

    @Override
    protected List<ReactPackage> getPackages() {
        return Arrays.<ReactPackage>asList(
            new MainReactPackage(),
            new BleManagerPackage() // <------ add the package
        );
    }

    ...
}
```
## Note
- Remember to use the `start` method before anything.
- If you have problem with old devices try avoid to connect/read/write to a peripheral during scan.
- Android API >= 23 require the ACCESS_COARSE_LOCATION permission to scan for peripherals. React Native >= 0.33 natively support PermissionsAndroid like in the example.
- Before write, read or start notification you need to call `retrieveServices` method

## Example
The easiest way to test is simple make your AppRegistry point to our example component, like this:
```javascript
// in your index.ios.js or index.android.js
import React, { Component } from 'react';
import {
  AppRegistry,
} from 'react-native';
import App from 'react-native-ble-manager/example/App' //<-- simply point to the example js!

AppRegistry.registerComponent('MyAwesomeApp', () => App);
```

Or, you can still look into the whole [example](https://github.com/innoveit/react-native-ble-manager/tree/master/example) folder for a standalone project.

## Methods

### start(options)
Init the module.
Returns a `Promise` object.
Don't call this multiple times.

__Arguments__
- `options` - `JSON`

The parameter is optional the configuration keys are:
- `showAlert` - `Boolean` - [iOS only] Show or hide the alert if the bluetooth is turned off during initialization
- `restoreIdentifierKey` - `String` - [iOS only] Unique key to use for CoreBluetooth state restoration
- `forceLegacy` - `Boolean` - [Android only] Force to use the LegacyScanManager

__Examples__
```js
BleManager.start({showAlert: false})
  .then(() => {
    // Success code
    console.log('Module initialized');
  });

```

### scan(serviceUUIDs, seconds, allowDuplicates, scanningOptions)
Scan for availables peripherals.
Returns a `Promise` object.

__Arguments__
- `serviceUUIDs` - `Array of String` - the UUIDs of the services to looking for. On Android the filter works only for 5.0 or newer.
- `seconds` - `Integer` - the amount of seconds to scan.
- `allowDuplicates` - `Boolean` - [iOS only] allow duplicates in device scanning
- `scanningOptions` - `JSON` - [Android only] after Android 5.0, user can control specific ble scan behaviors:
  - `numberOfMatches` - `Number` - corresponding to [`setNumOfMatches`](https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder.html#setNumOfMatches(int))
  - `matchMode` - `Number` - corresponding to [`setMatchMode`](https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder.html#setMatchMode(int))
  - `scanMode` - `Number` - corresponding to [`setScanMode`](https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder.html#setScanMode(int))


__Examples__
```js
BleManager.scan([], 5, true)
  .then(() => {
    // Success code
    console.log('Scan started');
  });

```

### stopScan()
Stop the scanning.
Returns a `Promise` object.

__Examples__
```js
BleManager.stopScan()
  .then(() => {
    // Success code
    console.log('Scan stopped');
  });

```

### connect(peripheralId)
Attempts to connect to a peripheral. In many case if you can't connect you have to scan for the peripheral before.
Returns a `Promise` object.

> In iOS, attempts to connect to a peripheral do not time out (please see [Apple's doc](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/1518766-connect)), so you might need to set a timer explicitly if you don't want this behavior.

__Arguments__
- `peripheralId` - `String` - the id/mac address of the peripheral to connect.

__Examples__
```js
BleManager.connect('XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX')
  .then(() => {
    // Success code
    console.log('Connected');
  })
  .catch((error) => {
    // Failure code
    console.log(error);
  });
```

### disconnect(peripheralId)
Disconnect from a peripheral.
Returns a `Promise` object.

__Arguments__
- `peripheralId` - `String` - the id/mac address of the peripheral to disconnect.

__Examples__
```js
BleManager.disconnect('XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX')
  .then(() => {
    // Success code
    console.log('Disconnected');
  })
  .catch((error) => {
    // Failure code
    console.log(error);
  });
```

### enableBluetooth() [Android only]
Create the request to the user to activate the bluetooth.
Returns a `Promise` object.

__Examples__
```js
BleManager.enableBluetooth()
  .then(() => {
    // Success code
    console.log('The bluetooth is already enabled or the user confirm');
  })
  .catch((error) => {
    // Failure code
    console.log('The user refuse to enable bluetooth');
  });
```

### checkState()
Force the module to check the state of BLE and trigger a BleManagerDidUpdateState event.

__Examples__
```js
BleManager.checkState();
```

### startNotification(peripheralId, serviceUUID, characteristicUUID)
Start the notification on the specified characteristic, you need to call `retrieveServices` method before.
Returns a `Promise` object.

__Arguments__
- `peripheralId` - `String` - the id/mac address of the peripheral.
- `serviceUUID` - `String` - the UUID of the service.
- `characteristicUUID` - `String` - the UUID of the characteristic.

__Examples__
```js
BleManager.startNotification('XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX', 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX', 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX')
  .then(() => {
    // Success code
    console.log('Notification started');
  })
  .catch((error) => {
    // Failure code
    console.log(error);
  });
```

### stopNotification(peripheralId, serviceUUID, characteristicUUID)
Stop the notification on the specified characteristic.
Returns a `Promise` object.

__Arguments__
- `peripheralId` - `String` - the id/mac address of the peripheral.
- `serviceUUID` - `String` - the UUID of the service.
- `characteristicUUID` - `String` - the UUID of the characteristic.

### read(peripheralId, serviceUUID, characteristicUUID)
Read the current value of the specified characteristic, you need to call `retrieveServices` method before.
Returns a `Promise` object.

__Arguments__
- `peripheralId` - `String` - the id/mac address of the peripheral.
- `serviceUUID` - `String` - the UUID of the service.
- `characteristicUUID` - `String` - the UUID of the characteristic.

__Examples__
```js
BleManager.read('XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX', 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX', 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX')
  .then((readData) => {
    // Success code
    console.log('Read: ' + readData);

    const buffer = Buffer.Buffer.from(readData);    //https://github.com/feross/buffer#convert-arraybuffer-to-buffer
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

__Arguments__
- `peripheralId` - `String` - the id/mac address of the peripheral.
- `serviceUUID` - `String` - the UUID of the service.
- `characteristicUUID` - `String` - the UUID of the characteristic.
- `data` - `Byte array` - the data to write.
- `maxByteSize` - `Integer` - specify the max byte size before splitting message

__Data preparation__

If your data is not in byte array format you should convert it first. For strings you can use `convert-string` or other npm package in order to achieve that.
Install the package first:
```shell
npm install convert-string
```
Then use it in your application:
```js
// Import/require in the beginning of the file
import { stringToBytes } from 'convert-string';
// Convert data to byte array before write/writeWithoutResponse
const data = stringToBytes(yourStringData);
```
Feel free to use other packages or google how to convert into byte array if your data has other format.

__Examples__
```js
BleManager.write('XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX', 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX', 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX', data)
  .then(() => {
    // Success code
    console.log('Write: ' + data);
  })
  .catch((error) => {
    // Failure code
    console.log(error);
  });
```

### writeWithoutResponse(peripheralId, serviceUUID, characteristicUUID, data, maxByteSize, queueSleepTime)
Write without response to the specified characteristic, you need to call `retrieveServices` method before.
Returns a `Promise` object.

__Arguments__
- `peripheralId` - `String` - the id/mac address of the peripheral.
- `serviceUUID` - `String` - the UUID of the service.
- `characteristicUUID` - `String` - the UUID of the characteristic.
- `data` - `Byte array` - the data to write.
- `maxByteSize` - `Integer` - (Optional) specify the max byte size
- `queueSleepTime` - `Integer` - (Optional) specify the wait time before each write if the data is greater than maxByteSize

__Data preparation__

If your data is not in byte array format check info for the write function above.

__Example__
```js
BleManager.writeWithoutResponse('XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX', 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX', 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX', data)
  .then(() => {
    // Success code
    console.log('Writed: ' + data);
  })
  .catch((error) => {
    // Failure code
    console.log(error);
  });
```

### readRSSI(peripheralId)
Read the current value of the RSSI.
Returns a `Promise` object.

__Arguments__
- `peripheralId` - `String` - the id/mac address of the peripheral.

__Examples__
```js
BleManager.readRSSI('XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX')
  .then((rssi) => {
    // Success code
    console.log('Current RSSI: ' + rssi);
  })
  .catch((error) => {
    // Failure code
    console.log(error);
  });
```

### requestConnectionPriority(peripheralId, connectionPriority) [Android only API 21+]
Request a connection parameter update.
Returns a `Promise` object.

__Arguments__
- `peripheralId` - `String` - the id/mac address of the peripheral.
- `connectionPriority` - `Integer` - the connection priority to be requested, as follows:
    - 0 - balanced priority connection
    - 1 - high priority connection
    - 2 - low power priority connection

__Examples__
```js
BleManager.requestConnectionPriority('XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX', 1)
.then((status) => {
  // Success code
  console.log('Requested connection priority');
})
.catch((error) => {
  // Failure code
  console.log(error);
});
```

### requestMTU(peripheralId, mtu) [Android only API 21+]
Request an MTU size used for a given connection.
Returns a `Promise` object.

__Arguments__
- `peripheralId` - `String` - the id/mac address of the peripheral.
- `mtu` - `Integer` - the MTU size to be requested in bytes.

__Examples__
```js
BleManager.requestMTU('XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX', 512)
.then((mtu) => {
  // Success code
  console.log('MTU size changed to ' + mtu + ' bytes');
})
.catch((error) => {
  // Failure code
  console.log(error);
});
```

### retrieveServices(peripheralId)
Retrieve the peripheral's services and characteristics.
Returns a `Promise` object.

__Arguments__
- `peripheralId` - `String` - the id/mac address of the peripheral.
- `serviceUUIDs` - `String[]` - [iOS only] only retrieve these services.

__Examples__
```js
BleManager.retrieveServices('XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX')
  .then((peripheralInfo) => {
    // Success code
    console.log('Peripheral info:', peripheralInfo);
  });  
```

### refreshCache(peripheralId) [Android only]
refreshes the peripheral's services and characteristics cache
Returns a `Promise` object.

__Arguments__
- `peripheralId` - `String` - the id/mac address of the peripheral.

__Examples__
```js
BleManager.refreshCache('XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX')
  .then((peripheralInfo) => {
    // Success code
    console.log('cache refreshed!')
  })
  .cache((error) => {
    console.error(error)
  }); 
```


### getConnectedPeripherals(serviceUUIDs)
Return the connected peripherals.
Returns a `Promise` object.

__Arguments__
- `serviceUUIDs` - `Array of String` - the UUIDs of the services to looking for.

__Examples__
```js
BleManager.getConnectedPeripherals([])
  .then((peripheralsArray) => {
    // Success code
    console.log('Connected peripherals: ' + peripheralsArray.length);
  });

```

### createBond(peripheralId) [Android only]
Start the bonding (pairing) process with the remote device.
Returns a `Promise` object. The promise is resolved when either `new bond successfully created` or `bond already existed`, otherwise it will be rejected.

__Examples__
```js
BleManager.createBond(peripheralId)
  .then(() => {
    console.log('createBond success or there is already an existing one');
  })
  .catch(() => {
    console.log('fail to bond');
  })

```

### removeBond(peripheralId) [Android only]
Remove a paired device.
Returns a `Promise` object.

__Examples__
```js
BleManager.removeBond(peripheralId)
  .then(() => {
    console.log('removeBond success');
  })
  .catch(() => {
    console.log('fail to remove the bond');
  })

```


### getBondedPeripherals() [Android only]
Return the bonded peripherals.
Returns a `Promise` object.

__Examples__
```js
BleManager.getBondedPeripherals([])
  .then((bondedPeripheralsArray) => {
    // Each peripheral in returned array will have id and name properties
    console.log('Bonded peripherals: ' + bondedPeripheralsArray.length);
  });

```

### getDiscoveredPeripherals()
Return the discovered peripherals after a scan.
Returns a `Promise` object.

__Examples__
```js
BleManager.getDiscoveredPeripherals([])
  .then((peripheralsArray) => {
    // Success code
    console.log('Discovered peripherals: ' + peripheralsArray.length);
  });

```

### removePeripheral(peripheralId) [Android only]
Removes a disconnected peripheral from the cached list.
It is useful if the device is turned off, because it will be re-discovered upon turning on again.
Returns a `Promise` object.

__Arguments__
- `peripheralId` - `String` - the id/mac address of the peripheral.

### isPeripheralConnected(peripheralId, serviceUUIDs)
Check whether a specific peripheral is connected and return `true` or `false`.
Returns a `Promise` object.

__Examples__
```js
BleManager.isPeripheralConnected('XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX', [])
  .then((isConnected) => {
    if (isConnected) {
      console.log('Peripheral is connected!');
    } else {
      console.log('Peripheral is NOT connected!');
    }
  });

```

## Events
### BleManagerStopScan
The scanning for peripherals is ended.

__Arguments__
- `none`

__Examples__
```js
bleManagerEmitter.addListener(
    'BleManagerStopScan',
    () => {
        // Scanning is stopped
    }
);
```

###  BleManagerDidUpdateState
The BLE change state.

__Arguments__
- `state` - `String` - the new BLE state ('on'/'off').

__Examples__
```js
bleManagerEmitter.addListener(
    'BleManagerDidUpdateState',
    (args) => {
        // The new state: args.state
    }
);
```

###  BleManagerDiscoverPeripheral
The scanning find a new peripheral.

__Arguments__
- `id` - `String` - the id of the peripheral
- `name` - `String` - the name of the peripheral
- `rssi` - ` Number` - the RSSI value
- `advertising` - `JSON` - the advertising payload, according to platforms:
    - [Android] contains the raw `bytes` and  `data` (Base64 encoded string)
    - [iOS] contains a JSON object with different keys according to [Apple's doc](https://developer.apple.com/documentation/corebluetooth/cbcentralmanagerdelegate/advertisement_data_retrieval_keys?language=objc), here are some examples:
      - `kCBAdvDataChannel` - `Number`
      - `kCBAdvDataIsConnectable` - `Number`
      - `kCBAdvDataLocalName` - `String`
      - `kCBAdvDataManufacturerData` - `JSON` - contains the raw `bytes` and  `data` (Base64 encoded string)

__Examples__
```js
bleManagerEmitter.addListener(
    'BleManagerDiscoverPeripheral',
    (args) => {
        // The id: args.id
        // The name: args.name
    }
);
```

###  BleManagerDidUpdateValueForCharacteristic
A characteristic notify a new value.

__Arguments__
- `value` — `Array` — the read value
- `peripheral` — `String` — the id of the peripheral
- `characteristic` — `String` — the UUID of the characteristic
- `service` — `String` — the UUID of the characteristic

> Event will only be emitted after successful `startNotification`.

__Example__
```js
import { bytesToString } from 'convert-string';

async function connectAndPrepare(peripheral, service, characteristic) {
  // Connect to device
  await BleManager.connect(peripheral);
  // Before startNotification you need to call retrieveServices
  await BleManager.retrieveServices(peripheral);
  // To enable BleManagerDidUpdateValueForCharacteristic listener
  await BleManager.startNotification(peripheral, service, characteristic);
  // Add event listener
  bleManagerEmitter.addListener(
    'BleManagerDidUpdateValueForCharacteristic',
    ({ value, peripheral, characteristic, service }) => {
        // Convert bytes array to string
        const data = bytesToString(value);
        console.log(`Recieved ${data} for characteristic ${characteristic}`);
    }
  );
  // Actions triggereng BleManagerDidUpdateValueForCharacteristic event
}
```

###  BleManagerConnectPeripheral
A peripheral was connected.

__Arguments__
- `peripheral` - `String` - the id of the peripheral

###  BleManagerDisconnectPeripheral
A peripheral was disconnected.

__Arguments__
- `peripheral` - `String` - the id of the peripheral
