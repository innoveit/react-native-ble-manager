'use strict';
var React = require('react-native');
var bleManager = React.NativeModules.BleManager;

class BleManager  {

  constructor() {
    this.isPeripheralConnected = this.isPeripheralConnected.bind(this);
  }

  read(peripheralId, serviceUUID, characteristicUUID) {
    return new Promise((fulfill, reject) => {
      bleManager.read(peripheralId, serviceUUID, characteristicUUID, (success) => {
        fulfill(success);
      }, (fail) => {
        reject(fail);
      });
    });
  }

  write(peripheralId, serviceUUID, characteristicUUID, data, maxByteSize) {
    if (maxByteSize == null) {
      maxByteSize = 20;
    }
    return new Promise((fulfill, reject) => {
      bleManager.write(peripheralId, serviceUUID, characteristicUUID, data, maxByteSize, (success) => {
        fulfill();
      }, (fail) => {
        reject(fail);
      });
    });
  }

  writeWithoutResponse(peripheralId, serviceUUID, characteristicUUID, data, maxByteSize) {
    if (maxByteSize == null) {
      maxByteSize = 20;
    }
    return new Promise((fulfill, reject) => {
      bleManager.writeWithoutResponse(peripheralId, serviceUUID, characteristicUUID, data, maxByteSize, (success) => {
        fulfill();
      }, (fail) => {
        reject(fail);
      });
    });
  }

  connect(peripheralId) {
    return new Promise((fulfill, reject) => {
      bleManager.connect(peripheralId,(error) => {
        if (error) {
          reject(error);
        } else {
          fulfill();
        }        
      });
    });
  }

  disconnect(peripheralId) {
    return new Promise((fulfill, reject) => {
      bleManager.disconnect(peripheralId,(success) => {
        fulfill();
      }, (fail) => {
        reject(fail);
      });
    });
  }

  startNotification(peripheralId, serviceUUID, characteristicUUID) {
    return new Promise((fulfill, reject) => {
      bleManager.startNotification(peripheralId, serviceUUID, characteristicUUID, (success) => {
        fulfill();
      }, (fail) => {
        reject(fail);
      });
    });
  }

  stopNotification(peripheralId, serviceUUID, characteristicUUID) {
    return new Promise((fulfill, reject) => {
      bleManager.stopNotification(peripheralId, serviceUUID, characteristicUUID, (success) => {
        fulfill();
      }, (fail) => {
        reject(fail);
      });
    });
  }

  checkState() {
    bleManager.checkState();
  }

  scan(serviceUUIDs, seconds, allowDuplicates) {
    return new Promise((fulfill, reject) => {
      if (allowDuplicates == null) {
        allowDuplicates = false;
      }
      bleManager.scan(serviceUUIDs, seconds, allowDuplicates, (success) => {
        fulfill();
      });
    });
  }

  stopScan() {
    return new Promise((fulfill, reject) => {
      bleManager.stopScan((result) => {
        if (result != null) {
          reject(result);
        } else {
          fulfill();
        }
      });
    });
  }

  getConnectedPeripherals(serviceUUIDs) {
    return new Promise((fulfill, reject) => {
      bleManager.getConnectedPeripherals(serviceUUIDs, (result) => {
        if (result != null) {
          fulfill(result);
        } else {
          fulfill([]);
        }
      });
    });
  }

  getDiscoveredPeripherals() {
    return new Promise((fulfill, reject) => {
      bleManager.getDiscoveredPeripherals((result) => {
        if (result != null) {
          fulfill(result);
        } else {
          fulfill([]);
        }
      });
    });
  }

  isPeripheralConnected(peripheralId, serviceUUIDs) {
    return this.getConnectedPeripherals(serviceUUIDs).then((result) => {
      if (result.find((p) => { return p.id === peripheralId; })) {
        return true;
      } else {
        return false;
      }
    });
  }
}

module.exports = new BleManager();
