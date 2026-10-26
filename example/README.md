# React Native BLE Manager Example
The example app is using expo to simplify management. 

Install the dependencies `npm i` then `npx expo prebuild`, now you have the two native projects ready.

---

Run example in iOS:

`npx expo run:ios`

To try the iOS 18+ accessory picker with a heart rate sensor advertising service
`180D`, opt in when generating the native project:

```sh
BLE_ACCESSORY_SETUP=1 npx expo prebuild --platform ios
BLE_ACCESSORY_SETUP=1 npx expo run:ios
```

Use **Set up accessory**, **List accessories**, **Connect accessory** and
**Forget accessory** in the scan screen. Replace `180D` in `app.config.js` and
the picker item in `ScanDevicesScreen.tsx` for your hardware. Wait for Bluetooth
to be on before connecting. With AccessorySetupKit enabled, normal iOS scans
only return accessories paired with this app; the default example keeps it off.
See the [accessory setup guide](../docs/accessory-setup.markdown) for configuration,
cancellation and error handling.

---

Run example in Android:

`npx expo run:android`

---

If you want to modify the library code directly from the created projects use `npm link react-native-ble-manager` , otherwise the code will be copied to node_modules folder.
