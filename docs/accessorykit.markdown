---
layout: page
title: AccessoryKit
permalink: /accessory-kit/
parent: Usage
---

This page helps you how to setup the accessory kit.

# AccessoryKit (IOS +18)

## Introduction 
The first step is to understand how the AccessoryKit API works on iOS. Starting with iOS 18, AccessoryKit provides a modern way to discover devices, offering a smoother user experience by leveraging the system’s "Settings Scan" to retrieve peripherals.
When an app needs to connect to a new peripheral, AccessoryKit opens a Peripheral Picker. If the user has previously connected to the device using this API, the picker is not required. Additionally, it can function similarly to how device pairing works on Android.

<small>
To get the same behavior on Android you can use the Companion Devices api.
</small>

To use this API, <b>you must include</b> two entries in your app’s plist.
* <b>NSAccessorySetupKitSupports:</b> An array of strings that indicates the wireless technologies AccessorySetupKit uses when discovering and configuring accessories.
* <b>NSAccessorySetupBluetoothServices:</b> An array of strings that represent the hexadecimal values of Bluetooth SIG-defined services or custom services for accessories your app configures.
* <b>NSAccessorySetupBluetoothNames:</b> An array of strings that represent the Bluetooth device names or substrings for accessories that your app configures.

To be able to find devices using Accessory Kit you need to supply three things per device:
- <b>name:</b> the device name, should be present inside NSAccessorySetupBluetoothNames in your Info.plist
- <b>serviceUUID:</b> the device serviceUUID, should be present inside NSAccessorySetupBluetoothServices in your Info.plist
- <b>productImage:</b> An image name without extension, added into your project through the next step.

### 1. Setting up an accessory image for the picker

* <b>Open the Asset Catalog:</b> In Xcode, go to the Assets.xcassets folder in your project navigator.
  If it doesn’t exist, right-click the project → New File… → Asset Catalog.
* Drag your image file (PNG or JPG.) into the Assets catalog. It will create an image set with the same name as the file.
* Give it a name, <b>keep that name in mind since you should pass exactly the same name when using "accessoriesScan" method.</b>

### 2.1 Expo

Find your <b>app.config.js</b> file and add these entries varying by your needs:
```js
    return {
        // Add inside your ios object.
        ios: {
            bundleIdentifier: 'it.innove.example.ble',
            infoPlist: {
                NSAccessorySetupKitSupports: ['Bluetooth'],
                NSAccessorySetupBluetoothServices: [
                    '0000180D-0000-1000-8000-00805F9B34FB', // Heart monitoring device, you can add another peripheral service uuid.
                ],
                NSAccessorySetupBluetoothNames: ['Polar'], // Add device name, 
            },
        }
    }
```
After adding your own entries make sure to prebuild your expo project again. That will regenerate your Info.plist based on app.config.js

```bash
npx expo prebuild --clean
```

### 2.2 React-native

Find your <b>Info.plist</b> file and add these entries varying by your needs:
```plist
    <key>NSAccessorySetupBluetoothNames</key>
    <array>
      <string>Polar</string> 
    </array>
    <key>NSAccessorySetupBluetoothServices</key>
    <array>
      <string>0000180D-0000-1000-8000-00805F9B34FB</string>
    </array>
    <key>NSAccessorySetupKitSupports</key>
    <array>
      <string>Bluetooth</string>
    </array>
```
Now you should be able to use the api by rebuilding your react-native project.

### Usage

First, since only iOS 18 and later are supported, you should check whether the device supports the AccessoryKit API. If it’s not supported, the operation will fail safely, returning a rejected promise with an “unsupported” message.

```js
    const supported = await BleManager.getAccessoryKitSupported(); // returns true or false
```

Because devices connected via AccessoryKit no longer show up in the picker, it’s better to first check if one is already available, like this:
```js

    async function getAccessoriesKitDevices() {
        const supported = await BleManager.getAccessoryKitSupported();
        if (supported) {
            let accessories = await BleManager.getConnectedAccessories();
            if (!accessories.length) {
                accessories = await BleManager.accessoriesScan([
                    {
                        name: 'Polar',
                        productImage: "heart.fill",
                        serviceUUID: '0000180D-0000-1000-8000-00805F9B34FB',
                    },
                ]);
                // You can also get the same scanned devices using events.
            }
        }
        return accessories
    }
```
