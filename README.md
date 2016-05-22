# react-native-ble-manager
[![npm version](https://img.shields.io/npm/v/react-native-ble-manager.svg?style=flat)](https://www.npmjs.com/package/react-native-ble-manager)
[![npm downloads](https://img.shields.io/npm/dm/react-native-ble-manager.svg?style=flat)](https://www.npmjs.com/package/react-native-ble-manager)

This is a porting of https://github.com/don/cordova-plugin-ble-central project to React Native.

###Supported Platforms
- iOS
- Android (API 16)

##Methods
### connect(peripheralId)
Attempts to connect to a peripheral.
Returns a `Promise` object.

__Arguments__
- `peripheralId` - A `String`, the id/mac address of the peripheral to connect.

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
