'use strict';
var React = require('react-native');
var bleManager = React.NativeModules.BleManager;

class BleManager  {

  constructor() {
    this.isPeripheralConnected = this.isPeripheralConnected.bind(this);
  }

  read(peripheralId, serviceUUID, characteristicUUID) {
    return new Promise((fulfill, reject) => {
      bleManager.read(peripheralId, serviceUUID, characteristicUUID, (error, data) => {
        if (error) {
          reject(error);
        } else {
          fulfill(data);
        }
      });
    });
  }

  readRSSI(peripheralId) {
    return new Promise((fulfill, reject) => {
      bleManager.readRSSI(peripheralId, (error, rssi) => {
        if (error) {
          reject(error);
        } else {
          fulfill(rssi);
        }
      });
    });
  }

  refreshCache(peripheralId) {
    return new Promise((fulfill, reject) => {
      bleManager.refreshCache(peripheralId, (error, result) => {
        if (error) {
          reject(error);
        } else {
          fulfill(result);
        }
      });
    });
  }

  retrieveServices(peripheralId, services) {
    return new Promise((fulfill, reject) => {
      bleManager.retrieveServices(peripheralId, services, (error, peripheral) => {
        if (error) {
          reject(error);
        } else {
          fulfill(peripheral);
        }
      });
    });
  }

  write(peripheralId, serviceUUID, characteristicUUID, data, maxByteSize) {
    if (maxByteSize == null) {
      maxByteSize = 20;
    }
    return new Promise((fulfill, reject) => {
      bleManager.write(peripheralId, serviceUUID, characteristicUUID, data, maxByteSize, (error) => {
        if (error) {
          reject(error);
        } else {
          fulfill();
        }
      });
    });
  }

  writeWithoutResponse(peripheralId, serviceUUID, characteristicUUID, data, maxByteSize, queueSleepTime) {
    if (maxByteSize == null) {
      maxByteSize = 20;
    }
    if (queueSleepTime == null) {
      queueSleepTime = 10;
    }
    return new Promise((fulfill, reject) => {
      bleManager.writeWithoutResponse(peripheralId, serviceUUID, characteristicUUID, data, maxByteSize, queueSleepTime, (error) => {
        if (error) {
          reject(error);
        } else {
          fulfill();
        }
      });
    });
  }

  connect(peripheralId) {
    return new Promise((fulfill, reject) => {
      bleManager.connect(peripheralId, (error) => {
        if (error) {
          reject(error);
        } else {
          fulfill();
        }
      });
    });
  }

  createBond(peripheralId) {
    return new Promise((fulfill, reject) => {
      bleManager.createBond(peripheralId, (error) => {
        if (error) {
          reject(error);
        } else {
          fulfill();
        }
      });
    });
  }

  removeBond(peripheralId) {
    return new Promise((fulfill, reject) => {
      bleManager.removeBond(peripheralId, (error) => {
        if (error) {
          reject(error);
        } else {
          fulfill();
        }
      });
    });
  }

  disconnect(peripheralId, force=true) {
    return new Promise((fulfill, reject) => {
      bleManager.disconnect(peripheralId, force, (error) => {
        if (error) {
          reject(error);
        } else {
          fulfill();
        }
      });
    });
  }

  startNotification(peripheralId, serviceUUID, characteristicUUID) {
    return new Promise((fulfill, reject) => {
      bleManager.startNotification(peripheralId, serviceUUID, characteristicUUID, (error) => {
        if (error) {
          reject(error);
        } else {
          fulfill();
        }
      });
    });
  }

  stopNotification(peripheralId, serviceUUID, characteristicUUID) {
    return new Promise((fulfill, reject) => {
      bleManager.stopNotification(peripheralId, serviceUUID, characteristicUUID, (error) => {
        if (error) {
          reject(error);
        } else {
          fulfill();
        }
      });
    });
  }

  checkState() {
    bleManager.checkState();
  }

  start(options) {
    return new Promise((fulfill, reject) => {
      if (options == null) {
        options = {};
      }
      bleManager.start(options, (error) => {
        if (error) {
          reject(error);
        } else {
          fulfill();
        }
      });
    });
  }

  scan(serviceUUIDs, seconds, allowDuplicates, scanningOptions={}) {
    return new Promise((fulfill, reject) => {
      if (allowDuplicates == null) {
        allowDuplicates = false;
      }

      // (ANDROID) Match as many advertisement per filter as hw could allow
      // dependes on current capability and availability of the resources in hw.
      if (scanningOptions.numberOfMatches == null) {
        scanningOptions.numberOfMatches = 3;
      }

      // (ANDROID) Defaults to MATCH_MODE_AGGRESSIVE
      if (scanningOptions.matchMode == null) {
        scanningOptions.matchMode = 1;
      }

      // (ANDROID) Defaults to SCAN_MODE_LOW_POWER on android
      if (scanningOptions.scanMode == null) {
        scanningOptions.scanMode = 0;
      }

      bleManager.scan(serviceUUIDs, seconds, allowDuplicates, scanningOptions, (error) => {
        if (error) {
          reject(error);
        } else {
          fulfill();
        }
      });
    });
  }

  stopScan() {
    return new Promise((fulfill, reject) => {
      bleManager.stopScan((error) => {
        if (error != null) {
          reject(error);
        } else {
          fulfill();
        }
      });
    });
  }

  enableBluetooth() {
    return new Promise((fulfill, reject) => {
      bleManager.enableBluetooth((error) => {
        if (error != null) {
          reject(error);
        } else {
          fulfill();
        }
      });
    });
  }

  getConnectedPeripherals(serviceUUIDs) {
    return new Promise((fulfill, reject) => {
      bleManager.getConnectedPeripherals(serviceUUIDs, (error, result) => {
        if (error) {
          reject(error);
        } else {
          if (result != null) {
            fulfill(result);
          } else {
            fulfill([]);
          }
        }
      });
    });
  }

  getBondedPeripherals() {
    return new Promise((fulfill, reject) => {
      bleManager.getBondedPeripherals((error, result) => {
        if (error) {
          reject(error);
        } else {
          if (result != null) {
            fulfill(result);
          } else {
            fulfill([]);
          }
        }
      });
    });
  }

  getDiscoveredPeripherals() {
    return new Promise((fulfill, reject) => {
      bleManager.getDiscoveredPeripherals((error, result) => {
        if (error) {
          reject(error);
        } else {
          if (result != null) {
            fulfill(result);
          } else {
            fulfill([]);
          }
        }
      });
    });
  }

  removePeripheral(peripheralId) {
    return new Promise((fulfill, reject) => {
      bleManager.removePeripheral(peripheralId, (error) => {
        if (error) {
          reject(error);
        } else {
          fulfill();
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

  requestConnectionPriority(peripheralId, connectionPriority) {
    return new Promise((fulfill, reject) => {
      bleManager.requestConnectionPriority(peripheralId, connectionPriority, (error, status) => {
        if (error) {
          reject(error);
        } else {
          fulfill(status);
        }
      });
    });
  }

  requestMTU(peripheralId, mtu) {
    return new Promise((fulfill, reject) => {
      bleManager.requestMTU(peripheralId, mtu, (error, mtu) => {
        if (error) {
          reject(error);
        } else {
          fulfill(mtu);
        }
      });
    });
  }
}

module.exports = new BleManager();
