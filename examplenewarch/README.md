# Bare React Native App with new arch enabled.

App to test new arch mode.
For testing codegen we actually need an valid react-native app as described in docs.

## Testing codegen

node node_modules/react-native/scripts/generate-codegen-artifacts.js \
--path . \
--outputPath ios/ \
--targetPlatform ios

## Testing the app with new arch

```bash
cd ios;
RCT_NEW_ARCH_ENABLED=1; # set up new arch flag to install all libraries in turbo modules mode. 
pod install; # install the libraries.
```
