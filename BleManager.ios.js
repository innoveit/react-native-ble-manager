/**
 * @providesModule BleManager
 * @flow
 */
'use strict';

var NativeBleManager = require('NativeModules').BleManager;

/**
 * High-level docs for the BleManagerModule iOS API can be written here.
 */

var BleManager = {
  test: function() {
    NativeBleManager.test();
  }
};

module.exports = BleManager;
