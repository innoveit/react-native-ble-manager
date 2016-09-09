# react-native-ble-manager
[![npm version](https://img.shields.io/npm/v/react-native-ble-manager.svg?style=flat)](https://www.npmjs.com/package/react-native-ble-manager)
[![npm downloads](https://img.shields.io/npm/dm/react-native-ble-manager.svg?style=flat)](https://www.npmjs.com/package/react-native-ble-manager)
[![GitHub issues](https://img.shields.io/github/issues/innoveit/react-native-ble-manager.svg?style=flat)](https://github.com/innoveit/react-native-ble-manager/issues)

This is a porting of https://github.com/don/cordova-plugin-ble-central project to React Native.

##Supported Platforms
- iOS
- Android (API 18)

##Install
```shell
npm i --save react-native-ble-manager
```
####iOS
- Open the node_modules/react-native-ble-manager/ios folder and drag BleManager.xcodeproj into your Libraries group.
- Check the "Build Phases"of your project and add "libBleManager.a" in the "Link Binary With Libraries" section.

####Android
#####Update Gradle Settings

```gradle
// file: android/settings.gradle
...

include ':react-native-ble-manager'
project(':react-native-ble-manager').projectDir = new File(rootProject.projectDir, '../node_modules/react-native-ble-manager/android')
```
#####Update Gradle Build

```gradle
// file: android/app/build.gradle
...

dependencies {
    ...
    compile project(':react-native-ble-manager')
}
```
#####Register React Package
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

##Basic Example
```js
class BleExample extends Component {

    constructor(){
        super()

        this.state = {
            ble:null,
            scanning:false,
        }
    }

    componentDidMount() {
        this.handleDiscoverPeripheral = this.handleDiscoverPeripheral.bind(this);

        NativeAppEventEmitter
            .addListener('BleManagerDiscoverPeripheral', this.handleDiscoverPeripheral );
    }

    handleScan() {
        BleManager.scan([], 30, true)
            .then((results) => console.log('Scanning...'); );
    }

    toggleScanning(bool){
        if (bool) {
            this.setState({scanning:true})
            this.scanning = setInterval( ()=> this.handleScan(), 3000);
        } else{
            this.setState({scanning:false, ble: null})
            clearInterval(this.scanning);
        }
    }

    handleDiscoverPeripheral(data){
        console.log('Got ble data', data);
        this.setState({ ble: data })
    }

    render() {

        const container = {
            flex: 1,
            justifyContent: 'center',
            alignItems: 'center',
            backgroundColor: '#F5FCFF',
        }

        const bleList = this.state.ble
            ? <Text> Device found: {this.state.ble.name} </Text>
            : <Text>no devices nearby</Text>

        return (
            <View style={container}>
                <TouchableHighlight style={{padding:20, backgroundColor:'#ccc'}} onPress={() => this.toggleScanning(!this.state.scanning) }>
                    <Text>Scan Bluetooth ({this.state.scanning ? 'on' : 'off'})</Text>
                </TouchableHighlight>

                {bleList}
            </View>
        );
    }
}
```

##Methods

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
Attempts to connect to a peripheral.
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

### writeWithoutResponse(peripheralId, serviceUUID, characteristicUUID, data, maxByteSize)
Write without response to the specified characteristic.
Returns a `Promise` object.

__Arguments__
- `peripheralId` - `String` - the id/mac address of the peripheral.
- `serviceUUID` - `String` - the UUID of the service.
- `characteristicUUID` - `String` - the UUID of the characteristic.
- `data` - `String` - the data to write in Base64 format.
- `maxByteSize` - `Integer` - specify the max byte size

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

###  BleManagerConnectPeripheral
A peripheral was connected.

__Arguments__
- `peripheral` - `String` - the id of the peripheral

###  BleManagerDisconnectPeripheral
A peripheral was disconnected.

__Arguments__
- `peripheral` - `String` - the id of the peripheral
