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
  EventCallback,
  BleConnectPeripheralEvent,
  BleDiscoverPeripheralEvent,
  BleStopScanEvent,
  BleManagerDidUpdateStateEvent,
  BleDisconnectPeripheralEvent,
  BleManagerDidUpdateValueForCharacteristicEvent,
  BleBondedPeripheralEvent,
  BleManagerCentralManagerWillRestoreState,
  BleManagerDidUpdateNotificationStateForEvent,
  BleManagerCompanionPeripheral,
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
   * Read the current value of the specified characteristic, you need to call `retrieveServices` method before.
   * 
   * @param peripheralId The id/mac address of the peripheral.
   * @param serviceUUID The UUID of the service.
   * @param characteristicUUID The UUID of the characteristic.
   * @returns Data as an array of numbers (which can be converted back to a Uint8Array (ByteArray) using something like [Buffer.from()](https://github.com/feross/buffer))
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
   * Read the current value of the specified descriptor, you need to call `retrieveServices` method before.
   * 
   * @param peripheralId The id/mac address of the peripheral.
   * @param serviceUUID The UUID of the service.
   * @param characteristicUUID The UUID of the characteristic.
   * @param descriptorUUID The UUID of the descriptor.
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
   * Write a value to the specified descriptor, you need to call `retrieveServices` method before.
   * 
   * @param peripheralId The id/mac address of the peripheral.
   * @param serviceUUID The UUID of the service.
   * @param characteristicUUID The UUID of the characteristic.
   * @param descriptorUUID The UUID of the descriptor.
   * @param data Data to write as an array of numbers (which can be converted from a Uint8Array (ByteArray) using something like [Buffer.toJSON().data](https://github.com/feross/buffer))
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
   * Read the current value of the RSSI.
   * 
   * @param peripheralId The id/mac address of the peripheral.
   * @returns A promise resolving with the updated RSSI (`number`) if it succeeds.
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
   * 
   * Refreshes the peripheral's services and characteristics cache.
   * 
   * @param peripheralId The id/mac address of the peripheral.
   * @returns A promise that resolves to a boolean indicating if gatt was successfully refreshed or not.
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
   * Retrieve the peripheral's services and characteristics.
   * 
   * @param peripheralId The id/mac address of the peripheral.
   * @param serviceUUIDs [iOS only] Optional filter of services to retrieve.
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
   * Write with response to the specified characteristic, you need to call `retrieveServices` method before.
   * 
   * @param peripheralId The id/mac address of the peripheral.
   * @param serviceUUID The UUID of the service.
   * @param characteristicUUID The UUID of the characteristic.
   * @param data Data to write as an array of numbers (which can be converted from a Uint8Array (ByteArray) using something like [Buffer.toJSON().data](https://github.com/feross/buffer))
   * @param maxByteSize Optional, defaults to 20
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
   * Write without response to the specified characteristic, you need to call `retrieveServices` method before.
   * 
   * @param peripheralId The id/mac address of the peripheral.
   * @param serviceUUID The UUID of the service.
   * @param characteristicUUID The UUID of the characteristic.
   * @param data Data to write as an array of numbers (which can be converted from a Uint8Array (ByteArray) using something like [Buffer.toJSON().data](https://github.com/feross/buffer))
   * @param maxByteSize Optional, defaults to 20
   * @param queueSleepTime Optional, defaults to 10. Only useful if data length is greater than maxByteSize.
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

  /**
   * Attempts to connect to a peripheral. In many case if you can't connect you have to scan for the peripheral before.
   * 
   * > In iOS, attempts to connect to a peripheral do not time out (please see [Apple's doc](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/1518766-connect)), so you might need to set a timer explicitly if you don't want this behavior.
   */
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
   * 
   * Start the bonding (pairing) process with the remote device.
   * If you pass peripheralPin (optional), bonding will be auto (without manually entering the pin).
   * > Ensure to make one bond request at a time.
   * 
   * @param peripheralId The id/mac address of the peripheral.
   * @param peripheralPin Optional. will be used to auto-bond if possible.
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
   * 
   * Remove a paired device.
   * 
   * @param peripheralId The id/mac address of the peripheral
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
   * Disconnect from a peripheral.
   * 
   * @param peripheralId The id/mac address of the peripheral to disconnect.
   * @param force [Android only] Defaults to true. Don't wait for the disconnect state to close the Gatt client.
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

  /**
   * Start the notification on the specified characteristic, you need to call `retrieveServices` method before.
   * 
   * Events will be send to `onDidUpdateValueForCharacteristic` when the peripheral notifies a new value for the characteristic. 
   * 
   * @param peripheralId The id/mac address of the peripheral.
   * @param serviceUUID The UUID of the service.
   * @param characteristicUUID The UUID of the characteristic.
   * @returns 
   */
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
   * 
   * Start the notification on the specified characteristic, you need to call `retrieveServices` method before.
   * The buffer collect messages until the buffer of messages bytes reaches the limit defined with the `buffer` argument and then emit all the collected data.
   * Useful to reduce the number of calls between the native and the react-native part in case of many messages.
   * 
   * @param peripheralId The id/mac address of the peripheral.
   * @param serviceUUID The UUID of the service.
   * @param characteristicUUID The UUID of the characteristic.
   * @param buffer The capacity of the buffer (bytes) stored before emitting the data for the characteristic.
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

  /**
   * Stop the notification on the specified characteristic.
   * 
   * @param peripheralId The id/mac address of the peripheral.
   * @param serviceUUID The UUID of the service.
   * @param characteristicUUID The UUID of the characteristic.
   * @returns 
   */
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

  /**
   * Force the module to check the state of the native BLE manager and trigger an event for `onDidUpdateState`.
   * @returns A promise containing the current BleState
   */
  checkState() {
    return new Promise<BleState>((fulfill, _) => {
      BleManagerModule.checkState((state: BleState) => {
        fulfill(state);
      });
    });
  }

  /**
   * Init the module. Don't call this multiple times.
   */
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
   * Scan for available peripherals.
   * 
   * See `onDiscoverPeripheral` to get live updates of devices being discovered.
   * 
   * See `getDiscoveredPeripherals` to get a list of discovered devices after a scan is completed.
   * 
   * @param scanningOptions Optional map of properties to fine-tune scan behavior, see DOCS.
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

  /**
   * Stop the scanning.
   */
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
   * Return the connected peripherals.
   * 
   * > In Android, Peripherals "advertising" property can be not set!
   * > Will be available if peripheral was found through scan before connect.
   * > This matches to current Android Bluetooth design specification.
   * 
   * @param serviceUUIDs [iOS only] Optional, only retrieve peripherals with these services. Ignored in Android.
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
   * 
   * Return the bonded peripherals.
   * 
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

  /**
   * Return the discovered peripherals after a scan.
   */
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
   * 
   * Removes a disconnected peripheral from the cached list.
   * It is useful if the device is turned off, because it will be re-discovered upon turning on again.
   * 
   * @param peripheralId The id/mac address of the peripheral.
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
   * Check whether a specific peripheral is connected and return `true` or `false`.
   * 
   * @param peripheralId The id/mac address of the peripheral.
   * @param serviceUUIDs [iOS only] Optional, only retrieve peripherals with these services. Ignored in Android.
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
   * Checks whether the scan is in progress and return `true` or `false`.
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
   * @param peripheralId The id/mac address of the peripheral.
   * @param connectionPriority The connection priority to be requested
   * @returns A promise that resolves with a boolean indicating of the connection priority was changed successfully, or rejects with an error message.
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
   * 
   * Request an MTU size used for a given connection.
   * 
   * @param peripheralId The id/mac address of the peripheral.
   * @param mtu Size to be requested, in bytes.
   * @returns A promise resolving with the negotiated MTU if it succeeded. Beware that it might not be the one requested due to device's BLE limitations on both side of the negotiation.
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
   * Retrieve associated peripherals (from companion manager).
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
   * 
   * Remove an associated peripheral.
   * 
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
   * Check if current device supports the companion device manager.
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
   * Scan for companion devices.
   * 
   * Rejects if the companion device manager is not supported on this device.
   * 
   * The promise it will eventually resolve with either:
   * 
   * 1.  peripheral if user selects one
   * 2.  null if user "cancels" (i.e. doesn't select anything)
   * 
   * See `BleManager.supportsCompanion`.
   * 
   * See: https://developer.android.com/develop/connectivity/bluetooth/companion-device-pairing
   * 
   * @param serviceUUIDs List of service UUIDs to use as a filter
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
   * 
   * Create the request to set the name of the bluetooth adapter. (https://developer.android.com/reference/android/bluetooth/BluetoothAdapter#setName(java.lang.String))
   * 
   * @param name
   */
  setName(name: string) {
    BleManagerModule.setName(name);
  }

  /**
   * [iOS only]
   * @param peripheralId The id/mac address of the peripheral.
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
   * @param peripheralId The id/mac address of the peripheral.
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

  /**
   * The scanning found a new peripheral.
   */
  onDiscoverPeripheral(callback: EventCallback<BleDiscoverPeripheralEvent>): EventSubscription {
    return BleManagerModule.onDiscoverPeripheral(callback);
  }

  /**
   * The scanning for peripherals is ended.
   */
  onStopScan(callback: EventCallback<BleStopScanEvent>): EventSubscription {
    return BleManagerModule.onStopScan(callback);
  }

  /**
   * The BLE state changed.
   */
  onDidUpdateState(callback: EventCallback<BleManagerDidUpdateStateEvent>): EventSubscription {
    return BleManagerModule.onDidUpdateState(callback);
  }

  /**
   * A peripheral was connected.
   */
  onConnectPeripheral(callback: EventCallback<BleConnectPeripheralEvent>): EventSubscription {
    return BleManagerModule.onConnectPeripheral(callback);
  }

  /**
   * A peripheral was disconnected.
   */
  onDisconnectPeripheral(callback: EventCallback<BleDisconnectPeripheralEvent>): EventSubscription {
    return BleManagerModule.onDisconnectPeripheral(callback);
  }

  /**
   * A characteristic notified a new value.
   * 
   * > Event will only be emitted after successful `startNotification`.
   */
  onDidUpdateValueForCharacteristic(callback: EventCallback<BleManagerDidUpdateValueForCharacteristicEvent>): EventSubscription {
    return BleManagerModule.onDidUpdateValueForCharacteristic(callback);
  }

  /**
   * A bond with a peripheral was established.
   */
  onPeripheralDidBond(callback: EventCallback<BleBondedPeripheralEvent>): EventSubscription {
    return BleManagerModule.onPeripheralDidBond(callback);
  }

  /**
   * [iOS only]
   * 
   * This is fired when [`centralManager:WillRestoreState:`](https://developer.apple.com/documentation/corebluetooth/cbcentralmanagerdelegate/1518819-centralmanager) is called (app relaunched in the background to handle a bluetooth event).
   * 
   * _For more on performing long-term bluetooth actions in the background:_
   * 
   * [iOS Bluetooth State Preservation and Restoration](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html#//apple_ref/doc/uid/TP40013257-CH7-SW10)
   * 
   * [iOS Relaunch Conditions](https://developer.apple.com/documentation/technotes/tn3115-bluetooth-state-restoration-app-relaunch-rules/)
   */
  onCentralManagerWillRestoreState(callback: EventCallback<BleManagerCentralManagerWillRestoreState>): EventSubscription {
    return BleManagerModule.onCentralManagerWillRestoreState(callback);
  }

  /**
   * [iOS only]
   * 
   * The peripheral received a request to start or stop providing notifications for a specified characteristic's value.
   */
  onDidUpdateNotificationStateFor(callback: EventCallback<BleManagerDidUpdateNotificationStateForEvent>): EventSubscription {
    return BleManagerModule.onDidUpdateNotificationStateFor(callback);
  }

  /**
   * User picked a device to associate with.
   * 
   * Null if the request was cancelled by the user.
   */
  onCompanionPeripheral(callback: EventCallback<BleManagerCompanionPeripheral>): EventSubscription {
    return BleManagerModule.onCompanionPeripheral(callback);
  }
}

export default new BleManager();
