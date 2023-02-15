import { NativeModules } from 'react-native';
import {
  BleScanCallbackType,
  BleScanMatchCount,
  BleScanMatchMode,
  BleScanMode,
  ConnectionPriority,
  Peripheral,
  PeripheralInfo,
  ScanOptions,
  StartOptions
} from './types';

export * from './types';

var bleManager = NativeModules.BleManager;

class BleManager {
  constructor() {
    this.isPeripheralConnected = this.isPeripheralConnected.bind(this);
  }

  /**
   * 
   * @param peripheralId 
   * @param serviceUUID 
   * @param characteristicUUID 
   * @returns data as an array of numbers (which can be converted back to a Uint8Array (ByteArray) using something like [Buffer.from()](https://github.com/feross/buffer))
   */
  read(peripheralId: string, serviceUUID: string, characteristicUUID: string) {
    return new Promise<number[]>((fulfill, reject) => {
      bleManager.read(
        peripheralId,
        serviceUUID,
        characteristicUUID,
        (error: string | null, data: number[]) => {
          if (error) {
            reject(error);
          } else {
            fulfill(data);
          }
        }
      );
    });
  }

  /**
   * 
   * @param peripheralId 
   * @returns a promise resolving with the updated RSSI (`number`) if it succeeds.
   */
  readRSSI(peripheralId: string) {
    return new Promise<number>((fulfill, reject) => {
      bleManager.readRSSI(peripheralId, (error: string | null, rssi: number) => {
        if (error) {
          reject(error);
        } else {
          fulfill(rssi);
        }
      });
    });
  }

  /**
   * [Android only]
   * @param peripheralId 
   * @returns a promise that resolves to a boolean indicating if gatt was successfully refreshed or not.
   */
  refreshCache(peripheralId: string) {
    return new Promise<boolean>((fulfill, reject) => {
      bleManager.refreshCache(peripheralId, (error: string | null, result: boolean) => {
        if (error) {
          reject(error);
        } else {
          fulfill(result);
        }
      });
    });
  }

  /**
   * 
   * @param peripheralId 
   * @param serviceUUIDs [iOS only] optional filter of services to retrieve.
   * @returns 
   */
  retrieveServices(peripheralId: string, serviceUUIDs: string[] = []) {
    return new Promise<PeripheralInfo>((fulfill, reject) => {
      bleManager.retrieveServices(
        peripheralId,
        serviceUUIDs,
        (error: string | null, peripheral: PeripheralInfo) => {
          if (error) {
            reject(error);
          } else {
            fulfill(peripheral);
          }
        }
      );
    });
  }

  /**
   * 
   * @param peripheralId 
   * @param serviceUUID 
   * @param characteristicUUID 
   * @param data data to write as an array of numbers (which can be converted from a Uint8Array (ByteArray) using something like [Buffer.toJSON().data](https://github.com/feross/buffer))
   * @param maxByteSize optional, defaults to 20
   * @returns 
   */
  write(
    peripheralId: string,
    serviceUUID: string,
    characteristicUUID: string,
    data: number[],
    maxByteSize: number = 20
  ) {

    return new Promise<void>((fulfill, reject) => {
      bleManager.write(
        peripheralId,
        serviceUUID,
        characteristicUUID,
        data,
        maxByteSize,
        (error: string | null) => {
          if (error) {
            reject(error);
          } else {
            fulfill();
          }
        }
      );
    });
  }

  /**
   * 
   * @param peripheralId 
   * @param serviceUUID 
   * @param characteristicUUID 
   * @param data data to write as an array of numbers (which can be converted from a Uint8Array (ByteArray) using something like [Buffer.toJSON().data](https://github.com/feross/buffer))
   * @param maxByteSize optional, defaults to 20
   * @param queueSleepTime optional, defaults to 10. Only useful if data length is greater than maxByteSize.
   * @returns 
   */
  writeWithoutResponse(
    peripheralId: string,
    serviceUUID: string,
    characteristicUUID: string,
    data: number[],
    maxByteSize: number = 20,
    queueSleepTime: number = 10
  ) {

    return new Promise<void>((fulfill, reject) => {
      bleManager.writeWithoutResponse(
        peripheralId,
        serviceUUID,
        characteristicUUID,
        data,
        maxByteSize,
        queueSleepTime,
        (error: string | null) => {
          if (error) {
            reject(error);
          } else {
            fulfill();
          }
        }
      );
    });
  }

  connect(peripheralId: string) {
    return new Promise<void>((fulfill, reject) => {
      bleManager.connect(peripheralId, (error: string | null) => {
        if (error) {
          reject(error);
        } else {
          fulfill();
        }
      });
    });
  }

  /**
   * [Android only]
   * @param peripheralId 
   * @param peripheralPin optional. will be used to auto-bond if possible.
   * @returns 
   */
  createBond(peripheralId: string, peripheralPin: string | null = null) {
    return new Promise<void>((fulfill, reject) => {
      bleManager.createBond(peripheralId, peripheralPin, (error: string | null) => {
        if (error) {
          reject(error);
        } else {
          fulfill();
        }
      });
    });
  }

  /**
   * [Android only]
   * @param peripheralId 
   * @returns 
   */
  removeBond(peripheralId: string) {
    return new Promise<void>((fulfill, reject) => {
      bleManager.removeBond(peripheralId, (error: string | null) => {
        if (error) {
          reject(error);
        } else {
          fulfill();
        }
      });
    });
  }

  /**
   * 
   * @param peripheralId 
   * @param force [Android only] defaults to true.
   * @returns 
   */
  disconnect(peripheralId: string, force: boolean = true) {
    return new Promise<void>((fulfill, reject) => {
      bleManager.disconnect(peripheralId, force, (error: string | null) => {
        if (error) {
          reject(error);
        } else {
          fulfill();
        }
      });
    });
  }

  startNotification(peripheralId: string, serviceUUID: string, characteristicUUID: string) {
    return new Promise<void>((fulfill, reject) => {
      bleManager.startNotification(
        peripheralId,
        serviceUUID,
        characteristicUUID,
        (error: string | null) => {
          if (error) {
            reject(error);
          } else {
            fulfill();
          }
        }
      );
    });
  }

  /**
   * [Android only]
   * @param peripheralId 
   * @param serviceUUID 
   * @param characteristicUUID 
   * @param buffer 
   * @returns 
   */
  startNotificationUseBuffer(
    peripheralId: string,
    serviceUUID: string,
    characteristicUUID: string,
    buffer: number
  ) {
    return new Promise<void>((fulfill, reject) => {
      bleManager.startNotificationUseBuffer(
        peripheralId,
        serviceUUID,
        characteristicUUID,
        buffer,
        (error: string | null) => {
          if (error) {
            reject(error);
          } else {
            fulfill();
          }
        }
      );
    });
  }

  stopNotification(peripheralId: string, serviceUUID: string, characteristicUUID: string) {
    return new Promise<void>((fulfill, reject) => {
      bleManager.stopNotification(
        peripheralId,
        serviceUUID,
        characteristicUUID,
        (error: string | null) => {
          if (error) {
            reject(error);
          } else {
            fulfill();
          }
        }
      );
    });
  }

  checkState() {
    bleManager.checkState();
  }

  start(options?: StartOptions) {
    return new Promise<void>((fulfill, reject) => {
      if (options == null) {
        options = {};
      }
      bleManager.start(options, (error: string | null) => {
        if (error) {
          reject(error);
        } else {
          fulfill();
        }
      });
    });
  }

  /**
   * 
   * @param serviceUUIDs 
   * @param seconds amount of seconds to scan. if set to 0 or less, will scan until you call stopScan() or the OS stops the scan (background etc).
   * @param allowDuplicates [iOS only]
   * @param scanningOptions [Android only] optional map of properties to fine-tune scan behavior on android, see README.
   * @returns 
   */
  scan(
    serviceUUIDs: string[],
    seconds: number,
    allowDuplicates?: boolean,
    scanningOptions: ScanOptions = {}
  ) {

    return new Promise<void>((fulfill, reject) => {
      if (allowDuplicates == null) {
        allowDuplicates = false;
      }

      // (ANDROID) Match as many advertisement per filter as hw could allow
      // depends on current capability and availability of the resources in hw.
      if (scanningOptions.numberOfMatches == null) {
        scanningOptions.numberOfMatches = BleScanMatchCount.MaxAdvertisements;
      }

      // (ANDROID) Defaults to MATCH_MODE_AGGRESSIVE
      if (scanningOptions.matchMode == null) {
        scanningOptions.matchMode = BleScanMatchMode.Aggressive;
      }

      // (ANDROID) Defaults to SCAN_MODE_LOW_POWER
      if (scanningOptions.scanMode == null) {
        scanningOptions.scanMode = BleScanMode.LowPower;
      }

      // (ANDROID) Defaults to CALLBACK_TYPE_ALL_MATCHES 
      // WARN: sometimes, setting a scanSetting instead of leaving it untouched might result in unexpected behaviors.
      // https://github.com/dariuszseweryn/RxAndroidBle/issues/462
      if (scanningOptions.callbackType == null) {
        scanningOptions.callbackType = BleScanCallbackType.AllMatches;
      }

      // (ANDROID) Defaults to 0ms (report results immediately).
      if (scanningOptions.reportDelay == null) {
        scanningOptions.reportDelay = 0;
      }

      // (ANDROID) ScanFilter used to restrict search to devices with a specific advertising name.
      // https://developer.android.com/reference/android/bluetooth/le/ScanFilter.Builder#setDeviceName(java.lang.String)
      if (!scanningOptions.exactAdvertisingName
        || typeof scanningOptions.exactAdvertisingName !== 'string') {
        delete scanningOptions.exactAdvertisingName;
      }

      bleManager.scan(
        serviceUUIDs,
        seconds,
        allowDuplicates,
        scanningOptions,
        (error: string | null) => {
          if (error) {
            reject(error);
          } else {
            fulfill();
          }
        }
      );
    });
  }

  stopScan() {
    return new Promise<void>((fulfill, reject) => {
      bleManager.stopScan((error: string | null) => {
        if (error) {
          reject(error);
        } else {
          fulfill();
        }
      });
    });
  }

  /**
   * [Android only] triggers an ENABLE_REQUEST intent to the end-user to enable bluetooth.
   * @returns 
   */
  enableBluetooth() {
    return new Promise<void>((fulfill, reject) => {
      bleManager.enableBluetooth((error: string | null) => {
        if (error) {
          reject(error);
        } else {
          fulfill();
        }
      });
    });
  }

  /**
   * 
   * @param serviceUUIDs [optional] not used on android, optional on ios.
   * @returns 
   */
  getConnectedPeripherals(serviceUUIDs: string[] = []) {
    return new Promise<Peripheral[]>((fulfill, reject) => {

      bleManager.getConnectedPeripherals(serviceUUIDs, (error: string | null, result: Peripheral[] | null) => {
        if (error) {
          reject(error);
        } else {
          if (result) {
            fulfill(result);
          } else {
            fulfill([]);
          }
        }
      });
    });
  }

  /**
   * [Android only]
   * @returns 
   */
  getBondedPeripherals() {
    return new Promise<Peripheral[]>((fulfill, reject) => {
      bleManager.getBondedPeripherals((error: string | null, result: Peripheral[] | null) => {
        if (error) {
          reject(error);
        } else {
          if (result) {
            fulfill(result);
          } else {
            fulfill([]);
          }
        }
      });
    });
  }

  getDiscoveredPeripherals() {
    return new Promise<Peripheral[]>((fulfill, reject) => {
      bleManager.getDiscoveredPeripherals((error: string | null, result: Peripheral[] | null) => {
        if (error) {
          reject(error);
        } else {
          if (result) {
            fulfill(result);
          } else {
            fulfill([]);
          }
        }
      });
    });
  }

  /**
   * [Android only]
   * @param peripheralId 
   * @returns 
   */
  removePeripheral(peripheralId: string) {
    return new Promise<void>((fulfill, reject) => {
      bleManager.removePeripheral(peripheralId, (error: string | null) => {
        if (error) {
          reject(error);
        } else {
          fulfill();
        }
      });
    });
  }

  /**
   * @param peripheralId 
   * @param serviceUUIDs [optional] not used on android, optional on ios.
   * @returns 
   */
  isPeripheralConnected(peripheralId: string, serviceUUIDs: string[] = []) {
    return this.getConnectedPeripherals(serviceUUIDs).then(result => {
      if (result.find(p => p.id === peripheralId)) {
        return true;
      } else {
        return false;
      }
    });
  }

  /**
   * [Android only, API 21+]
   * @param peripheralId 
   * @param connectionPriority 
   * @returns a promise that resolves with a boolean indicating of the connection priority was changed successfully, or rejects with an error message.
   */
  requestConnectionPriority(peripheralId: string, connectionPriority: ConnectionPriority) {
    return new Promise<boolean>((fulfill, reject) => {
      bleManager.requestConnectionPriority(
        peripheralId,
        connectionPriority,
        (error: string | null, status: boolean) => {
          if (error) {
            reject(error);
          } else {
            fulfill(status);
          }
        }
      );
    });
  }


  /**
   * [Android only, API 21+]
   * @param peripheralId
   * @param mtu size to be requested, in bytes.
   * @returns a promise resolving with the negotiated MTU if it succeeded. Beware that it might not be the one requested due to device's BLE limitations on both side of the negotiation.
   */
  requestMTU(peripheralId: string, mtu: number) {
    return new Promise<number>((fulfill, reject) => {
      bleManager.requestMTU(peripheralId, mtu, (error: string | null, mtu: number) => {
        if (error) {
          reject(error);
        } else {
          fulfill(mtu);
        }
      });
    });
  }

  /**
   * [Android only]
   * @param name 
   */
  setName(name: string) {
    bleManager.setName(name);
  }
}

export default new BleManager();