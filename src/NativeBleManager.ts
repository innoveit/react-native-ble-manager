import { TurboModule, TurboModuleRegistry } from 'react-native';
// @ts-ignore Ignore since it comes from codegen types.
import type { EventEmitter } from 'react-native/Libraries/Types/CodegenTypes';

/**
 * This represents the Turbo Module version of react-native-ble-manager.
 * This adds the codegen definition to react-native generate the c++ bindings on compile time.
 * That should work only on 0.75 and higher.
 * Don't remove it! and please modify with caution! Knowing that can create wrong bindings into jsi and break at compile or execution time.
 *  - Knowing that also every type needs to match the current Objective C++ and Java callbacks types and callbacks type definitions and be aware of the current differences between implementation in both platforms.
 */
export interface Spec extends TurboModule {
  start(options: Object, callback: (error: CallbackError) => void): void;

  scan(
    serviceUUIDStrings: string[],
    timeoutSeconds: number,
    allowDuplicates: boolean,
    scanningOptions: Object,
    callback: (error: CallbackError) => void
  ): void;

  stopScan(callback: (error: CallbackError) => void): void;

  connect(
    peripheralUUID: string,
    options: Object,
    callback: (error: CallbackError) => void
  ): void;

  disconnect(
    peripheralUUID: string,
    force: boolean,
    callback: (error: CallbackError) => void
  ): void;

  retrieveServices(
    peripheralUUID: string,
    services: string[],
    callback: (error: CallbackError, peripheral: PeripheralInfo) => void
  ): void;

  readRSSI(
    peripheralUUID: string,
    callback: (error: string | null, rssi: number) => void
  ): void;

  readDescriptor(
    peripheralUUID: string,
    serviceUUID: string,
    characteristicUUID: string,
    descriptorUUID: string,
    callback: (error: string | null, data: number[]) => void
  ): void;

  writeDescriptor(
    peripheralUUID: string,
    serviceUUID: string,
    characteristicUUID: string,
    descriptorUUID: string,
    data: object[],
    callback: (error: string | null) => void
  ): void;

  getDiscoveredPeripherals(
    callback: (error: string | null, result: Peripheral[] | null) => void
  ): void;

  checkState(callback: (state: BleState) => void): void;

  write(
    peripheralUUID: string,
    serviceUUID: string,
    characteristicUUID: string,
    message: object[],
    maxByteSize: number,
    callback: (error: string | null) => void
  ): void;

  writeWithoutResponse(
    peripheralUUID: string,
    serviceUUID: string,
    characteristicUUID: string,
    message: object[],
    maxByteSize: number,
    queueSleepTime: number,
    callback: (error: string | null) => void
  ): void;

  read(
    peripheralUUID: string,
    serviceUUID: string,
    characteristicUUID: string,
    callback: (error: string | null, data: number[]) => void
  ): void;

  startNotification(
    peripheralUUID: string,
    serviceUUID: string,
    characteristicUUID: string,
    callback: (error: string | null) => void
  ): void;

  stopNotification(
    peripheralUUID: string,
    serviceUUID: string,
    characteristicUUID: string,
    callback: (error: string | null) => void
  ): void;

  getConnectedPeripherals(
    serviceUUIDStrings: string[],
    callback: (error: string | null, result: Peripheral[] | null) => void
  ): void;

  isPeripheralConnected(
    peripheralUUID: string,
    callback: (error: Peripheral[]) => void
  ): void;

  isScanning(callback: (error: string | null, status: boolean) => void): void;

  getMaximumWriteValueLengthForWithoutResponse(
    peripheralUUID: string,
    callback: (error: string | null, max: number) => void
  ): void;

  getMaximumWriteValueLengthForWithResponse(
    deviceUUID: string,
    callback: (error: string | null, max: number) => void
  ): void;

  enableBluetooth(callback: (error: string | null) => void): void;

  getBondedPeripherals(
    callback: (error: string | null, result: Peripheral[] | null) => void
  ): void;

  createBond(
    peripheralUUID: string,
    devicePin: string,
    callback: (error: string | null) => void
  ): void;

  removeBond(
    peripheralUUID: string,
    callback: (error: string | null) => void
  ): void;

  removePeripheral(
    peripheralUUID: string,
    callback: (error: string | null) => void
  ): void;

  requestMTU(
    peripheralUUID: string,
    mtu: number,
    callback: (error: string | null, mtu: number) => void
  ): void;

  requestConnectionPriority(
    peripheralUUID: string,
    connectionPriority: number,
    callback: (error: string | null, status: boolean) => void
  ): void;

  refreshCache(
    peripheralUUID: string,
    callback: (error: string | null, result: boolean) => void
  ): void;

  setName(name: string): void;

  getAssociatedPeripherals(
    callback: (error: string | null, peripherals: Peripheral[] | null) => void
  ): void;

  removeAssociatedPeripheral(
    peripheralUUID: string,
    callback: (error: string | null) => void
  ): void;

  supportsCompanion(callback: (supports: boolean) => void): void;

  companionScan(
    serviceUUIDs: string[],
    option: Object,
    callback: (error: string | null, peripheral: Peripheral | null) => void
  ): void;

  /**
   * Supported events.
   */
  readonly onDiscoverPeripheral: EventEmitter<Peripheral>;
  readonly onStopScan: EventEmitter<EventStopScan>;
  readonly onDidUpdateState: EventEmitter<EventDidUpdateState>;
  readonly onDidUpdateValueForCharacteristic: EventEmitter<EventDidUpdateValueForCharacteristic>;
  readonly onConnectPeripheral: EventEmitter<EventConnectPeripheral>;
  readonly onDisconnectPeripheral: EventEmitter<EventDisconnectPeripheral>;
  readonly onPeripheralDidBond: EventEmitter<EventPeripheralDidBond>;
  readonly onCentralManagerWillRestoreState: EventEmitter<EventCentralManagerWillRestoreState>;
  readonly onDidUpdateNotificationStateFor: EventEmitter<EventDidUpdateNotificationStateFor>;
  readonly onCompanionPeripheral: EventEmitter<EventCompanionPeripheral>;
  readonly onCompanionFailure: EventEmitter<EventCompanionFailure>;
}

export default TurboModuleRegistry.get<Spec>('BleManager') as Spec;

/** Turbo Module Type Definitions */
// These types are more loose than types.ts for simplicity and for codegen support.
// No interfaces or generics are currently supported.
export type BleScanCallbackType = number;
export type BleScanMatchCount = number;
export type BleScanMatchMode = number;
export type BleScanMode = number;
export type BleScanPhyMode = number;
export type CallbackError = string | null;
export type BleState = string;

export type Peripheral = {
  id: string;
  rssi: number;
  name: string | null;
  advertising: {
    isConnectable?: boolean;
    localName?: string | null;
    rawData?: {
      CDVType: number[];
      bytes: number[];
      data: string;
    };
    manufacturerData?:
      | {
          CDVType: number[];
          bytes: number[];
          data: string;
        }[]
      | null;
    manufacturerRawData?: {
      CDVType: number[];
      bytes: number[];
      data: string;
    } | null;
    serviceData?:
      | {
          CDVType: number[];
          bytes: number[];
          data: string;
        }[]
      | null;
    serviceUUIDs?: string[];
    txPowerLevel?: number;
  };
};

export type PeripheralInfo = {
  id: string;
  rssi: number;
  name: string | null;
  advertising: {
    isConnectable?: boolean;
    localName?: string | null;
    rawData?: {
      CDVType: number[];
      bytes: number[];
      data: string;
    } | null;
    manufacturerData?:
      | {
          CDVType: number[];
          bytes: number[];
          data: string;
        }[]
      | null;
    manufacturerRawData?: {
      CDVType: number[];
      bytes: number[];
      data: string;
    } | null;
    serviceData?:
      | {
          CDVType: number[];
          bytes: number[];
          data: string;
        }[]
      | null;
    serviceUUIDs?: string[];
    txPowerLevel?: number;
  };
  serviceUUIDs?: string[];
  characteristics?: {
    properties: {
      Broadcast?: string;
      Read?: string;
      WriteWithoutResponse?: string;
      Write?: string;
      Notify?: string;
      Indicate?: string;
      AuthenticatedSignedWrites?: string;
      ExtendedProperties?: string;
      NotifyEncryptionRequired?: string;
      IndicateEncryptionRequired?: string;
    };
    characteristic: string;
    service: string;
    descriptors?: {
      value: string;
      uuid: string;
    }[];
  }[];
  services?: { uuid: string }[];
};

export type EventStopScan = {
  status: number;
};

export type EventDidUpdateState = {
  state: string;
};

export type EventDiscoverPeripheral = {
  id: string;
  name: string;
  rssi: number;
  advertising: {
    isConnectable: boolean;
    serviceUUIDs: string[];
    manufacturerData: number[];
    serviceData: number[];
    txPowerLevel: number;
    rawData?: number | null;
  };
};

export type EventDidUpdateValueForCharacteristic = {
  value: number[];
  peripheral: string;
  characteristic: string;
  service: string;
};

export type EventConnectPeripheral = {
  peripheral: string;
  status?: number | null;
};

export type EventDisconnectPeripheral = {
  peripheral: string;
  status?: number | null;
  domain?: string | null;
  code?: number | null;
};

export type EventPeripheralDidBond = {
  id: string;
  name: string;
  rssi: number;
  advertising: {
    isConnectable: boolean;
    serviceUUIDs: string[];
    manufacturerData: number[];
    serviceData: number[];
    txPowerLevel: number;
    rawData?: number | null;
  };
};

export type EventCentralManagerWillRestoreState = {
  peripherals: {
    id: string;
    name: string;
    rssi: number;
    advertising: {
      isConnectable: boolean;
      serviceUUIDs: string[];
      manufacturerData: number[];
      serviceData: number[];
      txPowerLevel: number;
      rawData?: number | null;
    };
  }[];
};

export type EventDidUpdateNotificationStateFor = {
  peripheral: string;
  characteristic: string;
  isNotifying: boolean;
  domain?: string | null;
  code?: number | null;
};

export type EventCompanionPeripheral = {
  id: string;
  name: string;
  rssi: number;
  advertising: {
    isConnectable: boolean;
    serviceUUIDs: string[];
    manufacturerData: number[];
    serviceData: number[];
    txPowerLevel: number;
    rawData?: number | null;
  };
};

export type EventCompanionFailure = {
  error: string;
};
