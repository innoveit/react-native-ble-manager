# react-native-ble-manager
[![npm version](https://img.shields.io/npm/v/react-native-ble-manager.svg?style=flat)](https://www.npmjs.com/package/react-native-ble-manager)
[![npm downloads](https://img.shields.io/npm/dm/react-native-ble-manager.svg?style=flat)](https://www.npmjs.com/package/react-native-ble-manager)

This is a porting of https://github.com/don/cordova-plugin-ble-central project to React Native.

###Supported Platforms
- iOS
- Android (API 16)

##Methods

### scan(serviceUUIDs, seconds)
Scan for availables peripherals.
Returns a `Promise` object.

__Arguments__
- `serviceUUIDs` - `Array of String` - the UUIDs of the services to looking for.
- `seconds` - `Integer` - the amount of seconds to scan.

__Examples__
```js
BleManager.scan([])
  .then(() => {
    // Success code
    console.log('Scan started');
  });
  
```

### connect(peripheralId)
Attempts to connect to a peripheral.
Returns a `Promise` object.

__Arguments__
- `peripheralId` - `String` - the id/mac address of the peripheral to connect.

__Examples__
```js
BleManager.connect('4B28EF69-423D-FA86-01FA-CC6CB923A2C9')
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
BleManager.disconnect('4B28EF69-423D-FA86-01FA-CC6CB923A2C9')
  .then(() => {
    // Success code
    console.log('Connected');
  })
  .catch((error) => {
    // Failure code
    console.log(error);
  });
```
##Events
- BluetoothManagerStopScan
- BluetoothManagerDidUpdateState
- BluetoothManagerDiscoverPeripheral
- BluetoothManagerDidUpdateValueForCharacteristic
- BluetoothManagerDisconnectPeripheral
