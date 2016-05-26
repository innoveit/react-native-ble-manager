# react-native-ble-manager
[![npm version](https://img.shields.io/npm/v/react-native-ble-manager.svg?style=flat)](https://www.npmjs.com/package/react-native-ble-manager)
[![npm downloads](https://img.shields.io/npm/dm/react-native-ble-manager.svg?style=flat)](https://www.npmjs.com/package/react-native-ble-manager)

This is a porting of https://github.com/don/cordova-plugin-ble-central project to React Native.

##Supported Platforms
- iOS
- Android (API 16)

##Install
```shell
npm i --save react-native-ble-manager
```
####iOS
- Open the node_modules/react-native-ble-manager/ios folder and drag BleManager.xcodeproj into your Libraries group.
- Check the "Build Phases"of your project and add "libBleManager.a" in the "Link Binary With Libraries" section.

####Android
#####Update Gradle Settings

```
// file: android/settings.gradle
...

include ':react-native-ble-manager'
project(':react-native-ble-manager').projectDir = new File(rootProject.projectDir, '../node_modules/react-native-ble-manager/android')
```
#####Update Gradle Build

```
// file: android/app/build.gradle
...

dependencies {
    ...
    compile project(':react-native-ble-manager')
}
```
#####Register React Package
```
...
import it.innove.BleManagerPackage; // <--- import

public class MainActivity extends ReactActivity {

    ...

    @Override
    protected List<ReactPackage> getPackages() {
        return Arrays.<ReactPackage>asList(
            new MainReactPackage(),
            new BleManagerPackage(this) // <------ add the package
        );
    }

    ...
}
```


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
    console.log('Disconnected');
  })
  .catch((error) => {
    // Failure code
    console.log(error);
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
- `peripheralId` - `String` - the id/mac address of the peripheral to disconnect.
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

##Events
### BleManagerStopScan
The scanning for peripherals is ended.

__Arguments__
- `none`

__Examples__
```js
NativeAppEventEmitter.addListener(
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
NativeAppEventEmitter.addListener(
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
NativeAppEventEmitter.addListener(
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

###  BleManagerDisconnectPeripheral
A peripheral is disconnected.

__Arguments__
- `peripheral` - `String` - the id of the peripheral

