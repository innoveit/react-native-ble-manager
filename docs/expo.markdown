---
layout: page
title: Expo
permalink: /expo/
nav_order: 4
---

# Expo

You can use the library in Expo via a [development build](https://docs.expo.dev/develop/development-builds/introduction/).

Since Expo 52, it is possible to make full use of the new architecture of React Native and thus version 12.x of the library.

---

To help configure the app, we added a plugin from version 12.1.x, add the configuration in the `app.json` file

```js
{
    ...
    "plugins" : [
        ...
        ["react-native-ble-manager", { options }]
    ],
}
```

**Options**

| Platform| Name| Type | Default | Description |
| --- | --- | --- | --- | --- |
| Android | `neverForLocation` | `Boolean` | `false` | The BLE is not used for location |
| Android | `companionDeviceEnabled` | `Boolean` | `false` | You are using the companion device |
| Android | `isBleRequired` | `Boolean` | `false` | The app require the BLE to work |
| iOS | `bluetoothAlwaysPermission` | `String | Boolean` | `'Allow $(PRODUCT_NAME) to connect to bluetooth devices'`  | The reason you use the BLE |

