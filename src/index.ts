import { EventSubscription, NativeModules } from 'react-native';
import {
  BleScanCallbackType,
  BleScanMatchCount,
  BleScanMatchMode,
  BleScanMode,
  BleState,
  ConnectOptions,
  ConnectionPriority,
  CompanionScanOptions,
  Peripheral,
  PeripheralInfo,
  ScanOptions,
  StartOptions,
} from './types';
import { CallbackError } from './NativeBleManager';
export * from './types';

// @ts-expect-error This applies the turbo module version only when turbo is enabled for backwards compatibility.
const isTurboModuleEnabled = global?.__turboModuleProxy != null;

const BleManagerModule = isTurboModuleEnabled
  ? require('./NativeBleManager').default
  : NativeModules.BleManager;

class BleManager {
  constructor() {
    if (!BleManagerModule) {
      throw new Error('BleManagerModule not found');
    }
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
      BleManagerModule.read(
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
   * @param serviceUUID
   * @param characteristicUUID
   * @param descriptorUUID
   * @returns data as an array of numbers (which can be converted back to a Uint8Array (ByteArray) using something like [Buffer.from()](https://github.com/feross/buffer))
   */
  readDescriptor(
    peripheralId: string,
    serviceUUID: string,
    characteristicUUID: string,
    descriptorUUID: string
  ) {
    return new Promise<number[]>((fulfill, reject) => {
      BleManagerModule.readDescriptor(
        peripheralId,
        serviceUUID,
        characteristicUUID,
        descriptorUUID,
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
   * @param serviceUUID
   * @param characteristicUUID
   * @param descriptorUUID
   * @param data data to write as an array of numbers (which can be converted from a Uint8Array (ByteArray) using something like [Buffer.toJSON().data](https://github.com/feross/buffer))
   * @returns
   */
  writeDescriptor(
    peripheralId: string,
    serviceUUID: string,
    characteristicUUID: string,
    descriptorUUID: string,
    data: number[]
  ) {
    return new Promise<void>((fulfill, reject) => {
      BleManagerModule.writeDescriptor(
        peripheralId,
        serviceUUID,
        characteristicUUID,
        descriptorUUID,
        data,
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
   * @returns a promise resolving with the updated RSSI (`number`) if it succeeds.
   */
  readRSSI(peripheralId: string) {
    return new Promise<number>((fulfill, reject) => {
      BleManagerModule.readRSSI(
        peripheralId,
        (error: string | null, rssi: number) => {
          if (error) {
            reject(error);
          } else {
            fulfill(rssi);
          }
        }
      );
    });
  }

  /**
   * [Android only]
   * @param peripheralId
   * @returns a promise that resolves to a boolean indicating if gatt was successfully refreshed or not.
   */
  refreshCache(peripheralId: string) {
    return new Promise<boolean>((fulfill, reject) => {
      BleManagerModule.refreshCache(
        peripheralId,
        (error: string | null, result: boolean) => {
          if (error) {
            reject(error);
          } else {
            fulfill(result);
          }
        }
      );
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
      BleManagerModule.retrieveServices(
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
      BleManagerModule.write(
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
      BleManagerModule.writeWithoutResponse(
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

  connect(peripheralId: string, options?: ConnectOptions) {
    return new Promise<void>((fulfill, reject) => {
      if (!options) {
        options = {};
      }
      BleManagerModule.connect(
        peripheralId,
        options,
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
   * @param peripheralPin optional. will be used to auto-bond if possible.
   * @returns
   */
  createBond(peripheralId: string, peripheralPin: string | null = null) {
    return new Promise<void>((fulfill, reject) => {
      BleManagerModule.createBond(
        peripheralId,
        peripheralPin,
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
   * @returns
   */
  removeBond(peripheralId: string) {
    return new Promise<void>((fulfill, reject) => {
      BleManagerModule.removeBond(peripheralId, (error: string | null) => {
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
      BleManagerModule.disconnect(
        peripheralId,
        force,
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

  startNotification(
    peripheralId: string,
    serviceUUID: string,
    characteristicUUID: string
  ) {
    return new Promise<void>((fulfill, reject) => {
      BleManagerModule.startNotification(
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
  startNotificationWithBuffer(
    peripheralId: string,
    serviceUUID: string,
    characteristicUUID: string,
    buffer: number
  ) {
    return new Promise<void>((fulfill, reject) => {
      BleManagerModule.startNotificationWithBuffer(
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

  stopNotification(
    peripheralId: string,
    serviceUUID: string,
    characteristicUUID: string
  ) {
    return new Promise<void>((fulfill, reject) => {
      BleManagerModule.stopNotification(
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
    return new Promise<BleState>((fulfill, _) => {
      BleManagerModule.checkState((state: BleState) => {
        fulfill(state);
      });
    });
  }

  start(options?: StartOptions) {
    return new Promise<void>((fulfill, reject) => {
      if (options == null) {
        options = {};
      }
      BleManagerModule.start(options, (error: string | null) => {
        if (error) {
          reject(error);
        } else {
          fulfill();
        }
      });
    });
  }

  /**
   * Check if the BLE manager has been started.
   * @returns boolean promise indicating if the manager is started.
   */
  isStarted(): Promise<boolean> {
    return new Promise((fulfill, reject) => {
      BleManagerModule.isStarted((error: CallbackError, started: boolean) => {
        if (error) {
          reject(error);
        } else {
          fulfill(started);
        }
      });
    });
  }

  /**
   *
   * @param serviceUUIDs
   * @param seconds amount of seconds to scan. if set to 0 or less, will scan until you call stopScan() or the OS stops the scan (background etc).
   * @param allowDuplicates [iOS only]
   * @param scanningOptions optional map of properties to fine-tune scan behavior, see DOCS.
   * @returns
   */
  scan(scanningOptions: ScanOptions = {}) {
    return new Promise<void>((fulfill, reject) => {
      if (scanningOptions.serviceUUIDs == null) {
        scanningOptions.serviceUUIDs = [];
      }
      if (scanningOptions.seconds == null) {
        scanningOptions.seconds = 0;
      }
      if (scanningOptions.allowDuplicates == null) {
        scanningOptions.allowDuplicates = false;
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

      // In Android ScanFilter used to restrict search to devices with a specific advertising name.
      // https://developer.android.com/reference/android/bluetooth/le/ScanFilter.Builder#setDeviceName(java.lang.String)
      // In iOS, this is a whole word match, not a partial search.
      if (!scanningOptions.exactAdvertisingName) {
        delete scanningOptions.exactAdvertisingName;
      } else {
        if (typeof scanningOptions.exactAdvertisingName === 'string') {
          scanningOptions.exactAdvertisingName = [
            scanningOptions.exactAdvertisingName,
          ];
        }
      }

      BleManagerModule.scan(scanningOptions, (error: string | null) => {
        if (error) {
          reject(error);
        } else {
          fulfill();
        }
      });
    });
  }

  stopScan() {
    return new Promise<void>((fulfill, reject) => {
      BleManagerModule.stopScan((error: string | null) => {
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
      BleManagerModule.enableBluetooth((error: string | null) => {
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
      BleManagerModule.getConnectedPeripherals(
        serviceUUIDs,
        (error: string | null, result: Peripheral[] | null) => {
          if (error) {
            reject(error);
          } else {
            if (result) {
              fulfill(result);
            } else {
              fulfill([]);
            }
          }
        }
      );
    });
  }

  /**
   * [Android only]
   * @returns
   */
  getBondedPeripherals() {
    return new Promise<Peripheral[]>((fulfill, reject) => {
      BleManagerModule.getBondedPeripherals(
        (error: string | null, result: Peripheral[] | null) => {
          if (error) {
            reject(error);
          } else {
            if (result) {
              fulfill(result);
            } else {
              fulfill([]);
            }
          }
        }
      );
    });
  }

  getDiscoveredPeripherals() {
    return new Promise<Peripheral[]>((fulfill, reject) => {
      BleManagerModule.getDiscoveredPeripherals(
        (error: string | null, result: Peripheral[] | null) => {
          if (error) {
            reject(error);
          } else {
            if (result) {
              fulfill(result);
            } else {
              fulfill([]);
            }
          }
        }
      );
    });
  }

  /**
   * [Android only]
   * @param peripheralId
   * @returns
   */
  removePeripheral(peripheralId: string) {
    return new Promise<void>((fulfill, reject) => {
      BleManagerModule.removePeripheral(
        peripheralId,
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
   * @param peripheralId
   * @param serviceUUIDs [optional] not used on android, optional on ios.
   * @returns
   */
  isPeripheralConnected(peripheralId: string, serviceUUIDs: string[] = []) {
    return this.getConnectedPeripherals(serviceUUIDs).then((result) => {
      if (result.find((p) => p.id === peripheralId)) {
        return true;
      } else {
        return false;
      }
    });
  }

  /**
   * @param peripheralId
   * @param serviceUUIDs [optional] not used on android, optional on ios.
   * @returns
   */
  isScanning() {
    return new Promise<boolean>((fulfill, reject) => {
      BleManagerModule.isScanning((error: string | null, status: boolean) => {
        if (error) {
          reject(error);
        } else {
          fulfill(status);
        }
      });
    });
  }

  /**
   * [Android only, API 21+]
   * @param peripheralId
   * @param connectionPriority
   * @returns a promise that resolves with a boolean indicating of the connection priority was changed successfully, or rejects with an error message.
   */
  requestConnectionPriority(
    peripheralId: string,
    connectionPriority: ConnectionPriority
  ) {
    return new Promise<boolean>((fulfill, reject) => {
      BleManagerModule.requestConnectionPriority(
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
      BleManagerModule.requestMTU(
        peripheralId,
        mtu,
        (error: string | null, mtu: number) => {
          if (error) {
            reject(error);
          } else {
            fulfill(mtu);
          }
        }
      );
    });
  }

  /**
   * [Android only, API 26+]
   *
   * @returns
   */
  getAssociatedPeripherals() {
    return new Promise<Peripheral[]>((fulfill, reject) => {
      BleManagerModule.getAssociatedPeripherals(
        (error: string | null, peripherals: Peripheral[] | null) => {
          if (error) {
            reject(error);
          } else {
            fulfill(peripherals || []);
          }
        }
      );
    });
  }

  /**
   * [Android only, API 26+]
   * @param peripheralId Peripheral to remove
   * @returns Promise that resolves once the peripheral has been removed. Rejects
   *          if no association is found.
   */
  removeAssociatedPeripheral(peripheralId: string) {
    return new Promise<void>((fulfill, reject) => {
      BleManagerModule.removeAssociatedPeripheral(
        peripheralId,
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
   *
   * Check if current device supports companion device manager.
   *
   * @return Promise resolving to a boolean.
   */
  supportsCompanion() {
    return new Promise<boolean>((fulfill) => {
      BleManagerModule.supportsCompanion((supports: boolean) =>
        fulfill(supports)
      );
    });
  }

  /**
   * [Android only, API 26+]
   *
   * Start companion scan.
   */
  companionScan(serviceUUIDs: string[], options: CompanionScanOptions = {}) {
    return new Promise<Peripheral | null>((fulfill, reject) => {
      BleManagerModule.companionScan(
        serviceUUIDs,
        options,
        (error: string | null, peripheral: Peripheral | null) => {
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
   * [Android only]
   * @param name
   */
  setName(name: string) {
    BleManagerModule.setName(name);
  }

  /**
   * [iOS only]
   * @param peripheralId
   * @returns
   */
  getMaximumWriteValueLengthForWithoutResponse(peripheralId: string) {
    return new Promise<number>((fulfill, reject) => {
      BleManagerModule.getMaximumWriteValueLengthForWithoutResponse(
        peripheralId,
        (error: string | null, max: number) => {
          if (error) {
            reject(error);
          } else {
            fulfill(max);
          }
        }
      );
    });
  }

  /**
   * [iOS only]
   * @param peripheralId
   * @returns
   */
  getMaximumWriteValueLengthForWithResponse(peripheralId: string) {
    return new Promise<number>((fulfill, reject) => {
      BleManagerModule.getMaximumWriteValueLengthForWithResponse(
        peripheralId,
        (error: string | null, max: number) => {
          if (error) {
            reject(error);
          } else {
            fulfill(max);
          }
        }
      );
    });
  }

  onDiscoverPeripheral(callback: any): EventSubscription {
    return BleManagerModule.onDiscoverPeripheral(callback);
  }

  onStopScan(callback: any): EventSubscription {
    return BleManagerModule.onStopScan(callback);
  }

  onDidUpdateState(callback: any): EventSubscription {
    return BleManagerModule.onDidUpdateState(callback);
  }

  onCentralManagerDidUpdateState(callback: any): EventSubscription {
    return BleManagerModule.onCentralManagerDidUpdateState(callback);
  }

  onConnectPeripheral(callback: any): EventSubscription {
    return BleManagerModule.onConnectPeripheral(callback);
  }

  onDisconnectPeripheral(callback: any): EventSubscription {
    return BleManagerModule.onDisconnectPeripheral(callback);
  }

  onDidUpdateValueForCharacteristic(callback: any): EventSubscription {
    return BleManagerModule.onDidUpdateValueForCharacteristic(callback);
  }

  onPeripheralDidBond(callback: any): EventSubscription {
    return BleManagerModule.onPeripheralDidBond(callback);
  }

  onCentralManagerWillRestoreState(callback: any): EventSubscription {
    return BleManagerModule.onCentralManagerWillRestoreState(callback);
  }

  onDidUpdateNotificationStateFor(callback: any): EventSubscription {
    return BleManagerModule.onDidUpdateNotificationStateFor(callback);
  }

  onCompanionPeripheral(callback: any): EventSubscription {
    return BleManagerModule.onCompanionPeripheral(callback);
  }

  onCompanionAvailability(callback: any): EventSubscription {
    return BleManagerModule.onCompanionAvailability(callback);
  }
}

export default new BleManager();
