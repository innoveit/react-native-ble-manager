# react-native-ble-manager

[![npm version](https://img.shields.io/npm/v/react-native-ble-manager.svg?style=flat)](https://www.npmjs.com/package/react-native-ble-manager)
[![npm downloads](https://img.shields.io/npm/dm/react-native-ble-manager.svg?style=flat)](https://www.npmjs.com/package/react-native-ble-manager)
[![GitHub issues](https://img.shields.io/github/issues/innoveit/react-native-ble-manager.svg?style=flat)](https://github.com/innoveit/react-native-ble-manager/issues)

A React Native Bluetooth Low Energy library.

Originally inspired by https://github.com/don/cordova-plugin-ble-central.

## Introduction

The library is a simple connection with the OS APIs, the BLE stack should be standard but often has different behaviors based on the device used, the operating system and the BLE chip it connects to. Before opening an issue verify that the problem is really the library.

## Requirements

RN 0.60+

RN 0.40-0.59 supported until 6.7.X
RN 0.30-0.39 supported until 2.4.3

## Supported Platforms

- iOS 10+
- Android (API 19+)

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
