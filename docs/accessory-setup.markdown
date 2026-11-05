---
layout: page
title: iOS accessory setup
permalink: /accessory-setup/
nav_order: 3
parent: Usage
---

# iOS accessory setup

AccessorySetupKit presents Apple's system picker to configure Bluetooth accessories on iOS 18 or newer. These APIs are separate from Android's `companionScan`, `getAssociatedPeripherals` and `removeAssociatedPeripheral`, which remain unchanged.

Setup does not connect to an accessory. After setup, use the shared BLE APIs: `start`, `connect`, `retrieveServices`, reads, writes and notifications.

## Configuration

Build with Xcode 16 or newer to enable AccessorySetupKit. With older SDKs, or on Android, older iOS versions and Mac Catalyst, `supportsAccessorySetup()` returns `false`. Accessory operations reject with `NOT_SUPPORTED`; `stopAccessoriesScan()` is a no-op.

Declare the supported services in your app's Info.plist. For Expo, add these entries to `ios.infoPlist` and regenerate the native project:

```js
infoPlist: {
  NSAccessorySetupKitSupports: ['Bluetooth'],
  NSAccessorySetupBluetoothServices: ['180D'],
}
```

For bare React Native, add the equivalent property list values:

```xml
<key>NSAccessorySetupKitSupports</key>
<array><string>Bluetooth</string></array>
<key>NSAccessorySetupBluetoothServices</key>
<array><string>180D</string></array>
```

Keep `NSBluetoothAlwaysUsageDescription` for the library's normal `start()` configuration. Declaring AccessorySetupKit support changes CoreBluetooth access: normal scans only return accessories paired with your app. Enable it deliberately rather than adding these keys to every app. See Apple's [setup guide](https://developer.apple.com/documentation/accessorysetupkit/discovering-and-configuring-accessories) and [CoreBluetooth integration example](https://developer.apple.com/videos/play/wwdc2024/10203/).

## Select and connect

Call the picker from a user action while the app is in the foreground. Each item describes a service to discover, a display label and an image. `name` is a picker label, not a Bluetooth name filter. `productImage` must name a bundled image asset or an SF Symbol. `serviceUUID` accepts a 16-bit or standard 128-bit UUID and must match a service declared in Info.plist.

```ts
import BleManager, { BleState, IOSAccessory } from 'react-native-ble-manager';

async function selectAccessory(): Promise<IOSAccessory | undefined> {
  if (!(await BleManager.supportsAccessorySetup())) return;

  const selected = await BleManager.accessoriesScan([
    { name: 'Heart rate sensor', productImage: 'heart.fill', serviceUUID: '180D' },
  ]);
  const accessory = selected[0];
  if (!accessory) return; // Dismissed without selecting an accessory.

  await BleManager.start({ showAlert: false });
  // Wait for onDidUpdateState to report "on" before connecting.
  // If already initialized and powered on, continue immediately.
  return accessory;
}

async function connectAccessory(accessory: IOSAccessory) {
  if (accessory.state !== 20) throw new Error('Accessory is not authorized.');
  if ((await BleManager.checkState()) !== BleState.On) {
    throw new Error('Wait for Bluetooth to be on before connecting.');
  }
  await BleManager.connect(accessory.id);
  return BleManager.retrieveServices(accessory.id);
}
```

`IOSAccessory` contains `{ id: string, name: string, state: number }`. The ID is the CoreBluetooth UUID used by `connect`. `state` is Apple's authorization state: `0` unauthorized, `10` awaiting authorization, `20` authorized. Check authorization before connecting. The result is not a scan advertisement and contains no RSSI or advertising data. `accessoriesScan()` returns newly added Bluetooth accessories. Use `getPairedAccessories()` to list previously configured ones, including after restarting the app.

## List, remove and cancel

```ts
const accessories = await BleManager.getPairedAccessories();
if (accessories[0]) {
  await BleManager.removeAccessory(accessories[0].id);
}

// While a picker request is pending:
BleManager.stopAccessoriesScan();
```

`removeAccessory()` removes the accessory's authorization through AccessorySetupKit. It is separate from closing a BLE connection with `disconnect()`. A missing accessory rejects with `ACCESSORY_NOT_FOUND`; a malformed ID rejects with `INVALID_ACCESSORY_ID`.

Only one accessory operation can run at a time. Another scan, list or removal request rejects with `ACCESSORY_SETUP_BUSY`, leaving the first request intact. Dismissing the picker normally resolves with an empty array when nothing was added. Calling `stopAccessoriesScan()` rejects the pending scan with `CANCELLED`; it does not cancel a list/removal operation or stop a BLE scan. Unexpected session invalidation rejects with `SESSION_INVALIDATED`. The library waits for session activation before showing the picker and preserves existing BLE manager state.

Errors reject the operation's promise. Invalid picker configuration rejects with `INVALID_ACCESSORY_SETUP`, `INVALID_DISPLAY_ITEMS`, `INVALID_DISPLAY_ITEM` or `INVALID_SERVICE_UUID`; system setup errors use `ACCESSORY_SETUP_FAILED`. These methods do not emit the Android Companion events.
