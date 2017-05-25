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
        minSdkVersion 18 // <--- make sure this is 18 or greater
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
        minSdkVersion 18 // <--- make sure this is 18 or greater
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
- Avoid to connect/read/write to a peripheral during scan.
- Android API >= 23 require the ACCESS_COARSE_LOCATION permission to scan for peripherals. React Native >= 0.33 natively support PermissionsAndroid like in the example.
- Before write, read or start notification you need to call `retrieveServices` method

## Example
Look in the [example](https://github.com/innoveit/react-native-ble-manager/tree/master/example) project.

## Methods

### start(options)
Init the module.
Returns a `Promise` object.

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

### scan(serviceUUIDs, seconds)
Scan for availables peripherals.
Returns a `Promise` object.

__Arguments__
- `serviceUUIDs` - `Array of String` - the UUIDs of the services to looking for. On Android the filter works only for 5.0 or newer.
- `seconds` - `Integer` - the amount of seconds to scan.
- `allowDuplicates` - `Boolean` - [iOS only] allow duplicates in device scanning

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
    console.log('The bluetooh is already enabled or the user confirm');
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
Start the notification on the specified characteristic.
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
Read the current value of the specified characteristic.
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
  })
  .catch((error) => {
    // Failure code
    console.log(error);
  });
```

### write(peripheralId, serviceUUID, characteristicUUID, data, maxByteSize)
Write with response to the specified characteristic.
Returns a `Promise` object.

__Arguments__
- `peripheralId` - `String` - the id/mac address of the peripheral.
- `serviceUUID` - `String` - the UUID of the service.
- `characteristicUUID` - `String` - the UUID of the characteristic.
- `data` - `String` - the data to write in Base64 format.
- `maxByteSize` - `Integer` - specify the max byte size before splitting message

To get the `data` into base64 format, you will need a library like `base64-js`. Install `base64-js`:

`npm install base64-js --save`

To format the data before calling the write function:
```js
var base64 = require('base64-js');
var data = base64.fromByteArray(yourData);
```

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
Write without response to the specified characteristic.
Returns a `Promise` object.

__Arguments__
- `peripheralId` - `String` - the id/mac address of the peripheral.
- `serviceUUID` - `String` - the UUID of the service.
- `characteristicUUID` - `String` - the UUID of the characteristic.
- `data` - `String` - the data to write in Base64 format.
- `maxByteSize` - `Integer` - (Optional) specify the max byte size
- `queueSleepTime` - `Integer` - (Optional) specify the wait time before each write if the data is greater than maxByteSize

To get the `data` into base64 format, you will need a library like `base64-js`. Install `base64-js`:

`npm install base64-js --save`

To format the data before calling the write function:
```js
var base64 = require('base64-js');
var data = base64.fromByteArray(yourData);
```

__Examples__
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

### retrieveServices(peripheralId)
Retrieve the peripheral's services and characteristics.
Returns a `Promise` object.

__Arguments__
- `peripheralId` - `String` - the id/mac address of the peripheral.

__Examples__
```js
BleManager.retrieveServices('XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX')
  .then((peripheralInfo) => {
    // Success code
    console.log('Peripheral info:', peripheralInfo);
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

### removePeripheral(peripheralId)
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
- `peripheral` - `String` - the id of the peripheral
- `characteristic` - `String` - the UUID of the characteristic
- `value` - `String` - the read value in Hex format

###  BleManagerConnectPeripheral
A peripheral was connected.

__Arguments__
- `peripheral` - `String` - the id of the peripheral

###  BleManagerDisconnectPeripheral
A peripheral was disconnected.

__Arguments__
- `peripheral` - `String` - the id of the peripheral
