# react-native-ble-manager

![GitHub Release](https://img.shields.io/github/v/release/innoveit/react-native-ble-manager?style=for-the-badge)
[![npm version](https://img.shields.io/npm/v/react-native-ble-manager.svg?style=for-the-badge)](https://www.npmjs.com/package/react-native-ble-manager)
[![npm downloads](https://img.shields.io/npm/dm/react-native-ble-manager.svg?style=for-the-badge)](https://www.npmjs.com/package/react-native-ble-manager)
[![GitHub issues](https://img.shields.io/github/issues/innoveit/react-native-ble-manager.svg?style=for-the-badge)](https://github.com/innoveit/react-native-ble-manager/issues)

A React Native Bluetooth Low Energy library.

Originally inspired by https://github.com/don/cordova-plugin-ble-central.

## Introduction

The library is a simple connection with the OS APIs, the BLE stack should be standard but often has different behaviors based on the device used, the operating system and the BLE chip it connects to. Before opening an issue verify that the problem is really the library.

## Requirements

RN 0.76+ only the new architecture is supported

RN 0.60-0.75 supported until 11.X  
RN 0.40-0.59 supported until 6.7.X  
RN 0.30-0.39 supported until 2.4.3  

## Supported Platforms

- iOS 15.1+
- Android (API 23+)

## Install

```shell
npm i --save react-native-ble-manager
```

The library support the react native autolink feature.

## Documentation

Read here [the full documentation](https://innoveit.github.io/react-native-ble-manager/)


## Example

The easiest way to test is simple make your AppRegistry point to our example component, like this:

```javascript
// in your index.ios.js or index.android.js
import React, { Component } from "react";
import { AppRegistry } from "react-native";
import App from "react-native-ble-manager/example/App"; //<-- simply point to the example js!
/* 
Note: The react-native-ble-manager/example directory is only included when cloning the repo, the above import will not work 
if trying to import react-native-ble-manager/example from node_modules
*/
AppRegistry.registerComponent("MyAwesomeApp", () => App);
```

Or, [use the example directly](example)


## Library development

- the library is written in typescript and needs to be built before being used for publication or local development, using the provided npm scripts in `package.json`.
- the local `example` project is configured to work with the locally built version of the library. To be able to run it, you need to build at least once the library so that its outputs listed as entrypoint in `package.json` (in the `dist` folder) are properly generated for consumption by the example project:

from the root folder:

```shell
npm install
npm run build
```

> if you are modifying the typescript files of the library (in `src/`) on the fly, you can run `npm run watch` instead. If you are modifying files from the native counterparts, you'll need to rebuild the whole app for your target environnement (`npm run android/ios`).

### Updating documentation

Edit files in `docs/`, then test locally with:
```shell
cd docs
bundle install
bundle exec jekyll serve --watch --baseurl /
```
Then open http://localhost:4000/ 

## Generate the native code from specs
A react-native project is needed to generate the code via *codegen*.

#### Generate Android code
- in the example folder generate the android project from expo: `npx expo prebuild --platform android`
- in the example/android folder run: `./gradlew generateCodegenArtifactsFromSchema` (you can add --info to have debug messages)
- if you have problems with the gradle cache `cd android && ./gradlew --stop && rm -rf ~/.gradle/caches`

#### Generate iOS code
- in the example folder generate the ios project from expo: `npx expo prebuild --platform ios`
- the codegen run during the first build, if you need to run it again use `pod install` in the ios folder
