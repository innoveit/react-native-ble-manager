import { NativeModules } from 'react-native';
import { ConnectionPriority, Peripheral, PeripheralInfo, ScanOptions, StartOptions } from './types';

const bleManager = NativeModules.BleManager;

class BleManager {
  constructor() {
    this.isPeripheralConnected = this.isPeripheralConnected.bind(this);
  }

  /**
   * Read the current value of the specified characteristic, you need to call {@link retrieveServices} method before.
   *
   * @param peripheralId the id/mac address of the peripheral.
   * @param serviceUUID the UUID of the service.
   * @param characteristicUUID the UUID of the characteristic.
   * @returns A {@link Promise} object.
   */
  read(peripheralId: string, serviceUUID: string, characteristicUUID: string) {
    return new Promise<any>((fulfill, reject) => {
      bleManager.read(
        peripheralId,
        serviceUUID,
        characteristicUUID,
        (error: Error | null, data: unknown) => {
          if (error) {
            reject(error);
          } else {
            fulfill(data);
          }
        },
      );
    });
  }

  /**
   * Read the current value of the RSSI.
   *
   * @param peripheralId the id/mac address of the peripheral.
   * @returns A {@link Promise} object.
   */
  readRSSI(peripheralId: string) {
    return new Promise<any>((fulfill, reject) => {
      bleManager.readRSSI(peripheralId, (error: Error | null, rssi: any) => {
        if (error) {
          reject(error);
        } else {
          fulfill(rssi);
        }
      });
    });
  }

  /**
   * refreshes the peripheral's services and characteristics cache.
   *
   * @param peripheralId the id/mac address of the peripheral.
   * @returns A {@link Promise} object.
   */
  refreshCache(peripheralId: string) {
    return new Promise<any>((fulfill, reject) => {
      bleManager.refreshCache(
        peripheralId,
        (error: Error | null, result: any) => {
          if (error) {
            reject(error);
          } else {
            fulfill(result);
          }
        },
      );
    });
  }

  /**
   * Retrieve the peripheral's services and characteristics.
   * @param peripheralId the id/mac address of the peripheral.
   * @param services [iOS only] only retrieve these services.
   * @returns A {@link Promise} object.
   */
  retrieveServices(peripheralId: string, services?: string[]) {
    return new Promise<PeripheralInfo>((fulfill, reject) => {
      bleManager.retrieveServices(
        peripheralId,
        services,
        (error: Error | null, peripheral: PeripheralInfo) => {
          if (error) {
            reject(error);
          } else {
            fulfill(peripheral);
          }
        },
      );
    });
  }

  /**
   * Write with response to the specified characteristic, you need to call {@link retrieveServices} method before.
   *
   * @param peripheralId the id/mac address of the peripheral.
   * @param serviceUUID the UUID of the service.
   * @param characteristicUUID the UUID of the characteristic.
   * @param data the data to write.
   * @param maxByteSize specify the max byte size before splitting message
   * @returns A {@link Promise} object.
   */
  write(
    peripheralId: string,
    serviceUUID: string,
    characteristicUUID: string,
    data: Uint8Array | number[],
    maxByteSize?: number,
  ) {
    if (maxByteSize == null) {
      maxByteSize = 20;
    }
    return new Promise<void>((fulfill, reject) => {
      bleManager.write(
        peripheralId,
        serviceUUID,
        characteristicUUID,
        data,
        maxByteSize,
        (error: Error | null) => {
          if (error) {
            reject(error);
          } else {
            fulfill();
          }
        },
      );
    });
  }

  /**
   * Write without response to the specified characteristic, you need to call {@link retrieveServices} method before.
   *
   * @param peripheralId the id/mac address of the peripheral.
   * @param serviceUUID the UUID of the service.
   * @param characteristicUUID the UUID of the characteristic.
   * @param data the data to write.
   * @param maxByteSize specify the max byte size before splitting message
   * @param queueSleepTime specify the wait time before each write if the data is greater than maxByteSize
   * @returns A {@link Promise} object.
   */
  writeWithoutResponse(
    peripheralId: string,
    serviceUUID: string,
    characteristicUUID: string,
    data: any,
    maxByteSize?: number,
    queueSleepTime?: number,
  ) {
    if (maxByteSize == null) {
      maxByteSize = 20;
    }
    if (queueSleepTime == null) {
      queueSleepTime = 10;
    }
    return new Promise<void>((fulfill, reject) => {
      bleManager.writeWithoutResponse(
        peripheralId,
        serviceUUID,
        characteristicUUID,
        data,
        maxByteSize,
        queueSleepTime,
        (error: Error | null) => {
          if (error) {
            reject(error);
          } else {
            fulfill();
          }
        },
      );
    });
  }

  /**
   * Attempts to connect to a peripheral. In many case if you can't connect you have to scan for the peripheral before.
   *
   * > In iOS, attempts to connect to a peripheral do not time out (please see [Apple's doc](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/1518766-connect)), so you might need to set a timer explicitly if you don't want this behavior.
   *
   * @param peripheralId the id/mac address of the peripheral to connect.
   * @returns A {@link Promise} object.
   */
  connect(peripheralId: string) {
    return new Promise<void>((fulfill, reject) => {
      bleManager.connect(peripheralId, (error: Error | null) => {
        if (error) {
          console.log(typeof error);
          reject(error);
        } else {
          fulfill();
        }
      });
    });
  }

  /**
   * [Android only]
   * Start the bonding (pairing) process with the remote device. If you pass peripheralPin (optional), bonding will be auto(without manual entering pin).
   *
   * The promise is resolved when either `new bond successfully created` or `bond already existed`, otherwise it will be rejected.
   * @param peripheralId the id/mac address of the peripheral.
   * @param peripheralPin the pin to use when connecting to the device
   * @returns A {@link Promise} object.
   */
  createBond(peripheralId: string, peripheralPin: string | null = null) {
    return new Promise<void>((fulfill, reject) => {
      bleManager.createBond(
        peripheralId,
        peripheralPin,
        (error: Error | null) => {
          if (error) {
            reject(error);
          } else {
            fulfill();
          }
        },
      );
    });
  }

  /**
   * [Android only] Remove a paired device.
   * @param peripheralId the id/mac address of the peripheral.
   * @returns A {@link Promise} object.
   */
  removeBond(peripheralId: string) {
    return new Promise<void>((fulfill, reject) => {
      bleManager.removeBond(peripheralId, (error: Error | null) => {
        if (error) {
          reject(error);
        } else {
          fulfill();
        }
      });
    });
  }

  /**
   * Disconnect from a peripheral.
   *
   * @param peripheralId the id/mac address of the peripheral to disconnect.
   * @param force [Android only] defaults to true, if true force closes gatt connection and send the BleManagerDisconnectPeripheral event immediately to Javascript, else disconnects the connection and waits for [`disconnected state`](https://developer.android.com/reference/android/bluetooth/BluetoothProfile#STATE_DISCONNECTED) to [`close the gatt connection`](https://developer.android.com/reference/android/bluetooth/BluetoothGatt#close()) and then sends the BleManagerDisconnectPeripheral to the Javascript
   * @returns A {@link Promise} object.
   */
  disconnect(peripheralId: string, force = true) {
    return new Promise<void>((fulfill, reject) => {
      bleManager.disconnect(peripheralId, force, (error: Error | null) => {
        if (error) {
          reject(error);
        } else {
          fulfill();
        }
      });
    });
  }

  /**
   * Start the notification on the specified characteristic, you need to call {@link retrieveServices} method before.
   *
   * @param peripheralId the id/mac address of the peripheral.
   * @param serviceUUID the UUID of the service.
   * @param characteristicUUID the UUID of the characteristic.
   * @returns A {@link Promise} object.
   */
  startNotification(
    peripheralId: string,
    serviceUUID: string,
    characteristicUUID: string,
  ) {
    return new Promise<void>((fulfill, reject) => {
      bleManager.startNotification(
        peripheralId,
        serviceUUID,
        characteristicUUID,
        (error: Error | null) => {
          if (error) {
            reject(error);
          } else {
            fulfill();
          }
        },
      );
    });
  }

  /**
   * [Android only]
   * Start the notification on the specified characteristic, you need to call {@link retrieveServices} method before. The buffer will collect a number or messages from the server and then emit once the buffer count it reached. Helpful to reducing the number or js bridge crossings when a characteristic is sending a lot of messages.
   *
   * @param peripheralId the id/mac address of the peripheral.
   * @param serviceUUID the UUID of the service.
   * @param characteristicUUID the UUID of the characteristic.
   * @param buffer a number of message to buffer prior to emit for the characteristic.
   * @returns A {@link Promise} object.
   */
  startNotificationUseBuffer(
    peripheralId: string,
    serviceUUID: string,
    characteristicUUID: string,
    buffer: number,
  ) {
    return new Promise<void>((fulfill, reject) => {
      bleManager.startNotificationUseBuffer(
        peripheralId,
        serviceUUID,
        characteristicUUID,
        buffer,
        (error: Error | null) => {
          if (error) {
            reject(error);
          } else {
            fulfill();
          }
        },
      );
    });
  }

  /**
   * Stop the notification on the specified characteristic.
   *
   * @param peripheralId the id/mac address of the peripheral.
   * @param serviceUUID the UUID of the service.
   * @param characteristicUUID the UUID of the characteristic.
   * @returns A {@link Promise} object.
   */
  stopNotification(
    peripheralId: string,
    serviceUUID: string,
    characteristicUUID: string,
  ) {
    return new Promise<void>((fulfill, reject) => {
      bleManager.stopNotification(
        peripheralId,
        serviceUUID,
        characteristicUUID,
        (error: Error | null) => {
          if (error) {
            reject(error);
          } else {
            fulfill();
          }
        },
      );
    });
  }

  /**
   * Force the module to check the state of BLE and trigger a BleManagerDidUpdateState event.
   */
  checkState() {
    bleManager.checkState();
  }

  /**
   * Init the module. Returns a Promise object. Don't call this multiple times.
   *
   * @param options Init options
   * @param options.showAlert [iOS only] Show or hide the alert if the bluetooth is turned off during initialization
   * @param options.restoreIdentifierKey [iOS only] Unique key to use for CoreBluetooth state restoration
   * @param options.queueIdentifierKey [iOS only] Unique key to use for a queue identifier on which CoreBluetooth events will be dispatched
   * @param options.forceLegacy [Android only] Force to use the LegacyScanManager
   * @returns A {@link Promise} object.
   */
  start(options?: StartOptions) {
    return new Promise<void>((fulfill, reject) => {
      if (options == null) {
        options = {};
      }
      bleManager.start(options, (error: Error | null) => {
        if (error) {
          reject(error);
        } else {
          fulfill();
        }
      });
    });
  }

  /**
   * Scan for availables peripherals.
   *
   * @param serviceUUIDs the UUIDs of the services to looking for. On Android the filter works only for 5.0 or newer.
   * @param seconds the amount of seconds to scan.
   * @param allowDuplicates [iOS only] allow duplicates in device scanning
   * @param scanningOptions [Android only] after Android 5.0, user can control specific ble scan behaviors
   * @param scanningOptions.numberOfMatches corresponding to [`setNumOfMatches`](https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder#setNumOfMatches(int))
   * @param scanningOptions.matchMode corresponding to [`setMatchMode`](https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder.html#setMatchMode(int))
   * @param scanningOptions.scanMode corresponding to [`setScanMode`](https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder.html#setScanMode(int))
   * @param scanningOptions.reportDelay corresponding to [`setReportDelay`](https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder.html#setReportDelay(long))
   * @returns A {@link Promise} object.
   */
  scan(
    serviceUUIDs: string[],
    seconds: number,
    allowDuplicates?: boolean,
    scanningOptions: ScanOptions = {},
  ) {
    return new Promise<void>((fulfill, reject) => {
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

      if (scanningOptions.reportDelay == null) {
        scanningOptions.reportDelay = 0;
      }

      bleManager.scan(
        serviceUUIDs,
        seconds,
        allowDuplicates,
        scanningOptions,
        (error: Error | null) => {
          if (error) {
            reject(error);
          } else {
            fulfill();
          }
        },
      );
    });
  }

  /**
   * Stop the scanning.
   *
   * @returns A {@link Promise} object.
   */
  stopScan() {
    return new Promise<void>((fulfill, reject) => {
      bleManager.stopScan((error: Error | null) => {
        if (error != null) {
          reject(error);
        } else {
          fulfill();
        }
      });
    });
  }

  /**
   * [Android only] Create the request to the user to activate the bluetooth.
   *
   * @returns A {@link Promise} object.
   */
  enableBluetooth() {
    return new Promise<void>((fulfill, reject) => {
      bleManager.enableBluetooth((error: Error | null) => {
        if (error != null) {
          reject(error);
        } else {
          fulfill();
        }
      });
    });
  }

  /**
   * Return the connected peripherals.
   *
   * @param serviceUUIDs the UUIDs of the services to looking for.
   * @returns A {@link Promise} object.
   */
  getConnectedPeripherals(serviceUUIDs?: string[] | null) {
    return new Promise<Peripheral[]>((fulfill, reject) => {
      bleManager.getConnectedPeripherals(
        serviceUUIDs == null ? [] : serviceUUIDs,
        (error: Error | null, result: Peripheral[] | null) => {
          if (error) {
            reject(error);
          } else {
            if (result != null) {
              fulfill(result);
            } else {
              fulfill([]);
            }
          }
        },
      );
    });
  }

  /**
   * [Android only] Return the bonded peripherals.
   *
   * @returns A {@link Promise} object.
   */
  getBondedPeripherals() {
    return new Promise<Peripheral[]>((fulfill, reject) => {
      bleManager.getBondedPeripherals(
        (error: Error | null, result: Peripheral[] | null) => {
          if (error) {
            reject(error);
          } else {
            if (result != null) {
              fulfill(result);
            } else {
              fulfill([]);
            }
          }
        },
      );
    });
  }

  /**
   * Return the discovered peripherals after a scan.
   *
   * @returns A {@link Promise} object.
   */
  getDiscoveredPeripherals() {
    return new Promise<Peripheral[]>((fulfill, reject) => {
      bleManager.getDiscoveredPeripherals(
        (error: Error | null, result: Peripheral[] | null) => {
          if (error) {
            reject(error);
          } else {
            if (result != null) {
              fulfill(result);
            } else {
              fulfill([]);
            }
          }
        },
      );
    });
  }

  /**
   * [Android only] Removes a disconnected peripheral from the cached list. It is useful if the device is turned off, because it will be re-discovered upon turning on again.
   * @param peripheralId the id/mac address of the peripheral.
   *
   * @returns A {@link Promise} object.
   */
  removePeripheral(peripheralId: string) {
    return new Promise<void>((fulfill, reject) => {
      bleManager.removePeripheral(peripheralId, (error: Error | null) => {
        if (error) {
          reject(error);
        } else {
          fulfill();
        }
      });
    });
  }

  /**
   * Check whether a specific peripheral is connected and resolve to true or false.
   *
   * @param peripheralId the id/mac address of the peripheral.
   * @param serviceUUIDs the UUIDs of the services to looking for.
   * @returns A {@link Promise} object.
   */
  isPeripheralConnected(peripheralId: string, serviceUUIDs?: string[] | null) {
    return this.getConnectedPeripherals(serviceUUIDs).then((result) => {
      if (
        result.find((p) => {
          return p.id === peripheralId;
        })
      ) {
        return true;
      } else {
        return false;
      }
    });
  }

  /**
   * [Android only] Check whether a specific peripheral is bonded (paired) and resolve to true or false.
   *
   * @param peripheralId the id/mac address of the peripheral.
   * @param serviceUUIDs the UUIDs of the services to looking for.
   * @returns A {@link Promise} object.
   */
  isPeripheralBonded(peripheralId: string) {
    return this.getBondedPeripherals().then((result) => {
      if (
        result.find((p) => {
          return p.id === peripheralId;
        })
      ) {
        return true;
      } else {
        return false;
      }
    });
  }

  /**
   * [Android only API 21+] Request a connection parameter update.
   * @param peripheralId the id/mac address of the peripheral.
   * @param connectionPriority the connection priority to be requested
   * @returns A {@link Promise} object.
   */
  requestConnectionPriority(
    peripheralId: string,
    connectionPriority: ConnectionPriority,
  ) {
    return new Promise<any>((fulfill, reject) => {
      bleManager.requestConnectionPriority(
        peripheralId,
        connectionPriority,
        (error: Error | null, status: any) => {
          if (error) {
            reject(error);
          } else {
            fulfill(status);
          }
        },
      );
    });
  }

  /**
   * [Android only API 21+] Request an MTU size used for a given connection.
   * @param peripheralId the id/mac address of the peripheral.
   * @param mtu the MTU size to be requested in bytes.
   * @returns A {@link Promise} object.
   */
  requestMTU(peripheralId: string, mtu: number) {
    return new Promise<any>((fulfill, reject) => {
      bleManager.requestMTU(
        peripheralId,
        mtu,
        (error: Error | null, resMtu: any) => {
          if (error) {
            reject(error);
          } else {
            fulfill(resMtu);
          }
        },
      );
    });
  }
}

const singleton = new BleManager();

export default singleton;