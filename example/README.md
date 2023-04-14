Install native pods with `npm i` then `npx pod-install`

Run example in iOS:
`npm run ios`

If error occurs using `npm run ios` its recommended you run the example directly in Xcode: (You might need to select a development team in Xcode or otherwise [setup your react-native env](https://reactnative.dev/docs/environment-setup)). These errors won't be communicated very clearly if relying soley on `npm run ios`.

Running in Xcode directly:

- Open `ios/example.xcworkspace` with Xcode:
- Ensure build target is selected under `Product > Destination > (Target)` (Note: Must test on a physical device in order for bluetooth to work)
- Run `Product > Run`

Run example in Android:

`npm run android`
