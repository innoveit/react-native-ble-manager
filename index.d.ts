declare module "react-native-ble-manager" {

  // android states: https://developer.android.com/reference/android/bluetooth/BluetoothAdapter#EXTRA_STATE
  // ios states: https://developer.apple.com/documentation/corebluetooth/cbcentralmanagerstate
  export enum BleState {
    Unknown = 'unknown', // [iOS only]
    Resetting = 'resetting', // [iOS only]
    Unsupported = 'unsupported',
    Unauthorized = 'unauthorized', // [iOS only]
    On = 'on',
    Off = 'off',
    TurningOn = 'turning_on', // [android only]
    TurningOff = 'turning_off', // [android only]
  }

  export interface Peripheral {
    id: string;
    rssi: number;
    name?: string;
    advertising: AdvertisingData;
  }

  export interface AdvertisingData {
    isConnectable?: boolean;
    localName?: string;
    manufacturerData?: CustomAdvertisingData,
    serviceData?: CustomAdvertisingData,
    serviceUUIDs?: string[];
    txPowerLevel?: number;
  }

  export interface CustomAdvertisingData {
    CDVType : 'ArrayBuffer',
    bytes: Uint8Array,
    data: string // base64-encoded string of the data
  }

  export interface StartOptions {
    showAlert?: boolean; // [iOS only]
    restoreIdentifierKey?: string; // [iOS only]
    queueIdentifierKey?: string; // [iOS only]
    forceLegacy?: boolean; // [android only]
  }

  export function start(options?: StartOptions): Promise<void>;

  // [android only]
  // https://developer.android.com/reference/android/bluetooth/le/ScanSettings
  export interface ScanOptions {
    numberOfMatches?: BleScanMatchCount;
    matchMode?: BleScanMatchMode;
    callbackType?: BleScanCallbackType;
    scanMode?: BleScanMode;
    reportDelay?: number;
    phy?: BleScanPhyMode;
    legacy?: boolean;
  }

  // [android only]
  export enum BleScanMode {
    Opportunistic = -1,
    LowPower = 0,
    Balanced = 1,
    LowLatency = 2,
  }

  // [android only]
  export enum BleScanMatchMode {
    Aggressive = 1,
    Sticky = 2,
  }

  // [android only]
  export enum BleScanCallbackType {
    AllMatches = 1,
    FirstMatch = 2,
    MatchLost = 4,
  }

  // [android only]
  export enum BleScanMatchCount {
    OneAdvertisement = 1,
    FewAdvertisements = 2,
    MaxAdvertisements = 3,
  }

  // [android only]
  export enum BleScanPhyMode {
    LE_1M = 1,
    LE_2M = 2,
    LE_CODED = 3,
    ALL_SUPPORTED = 255,
  }

  export function scan(
    serviceUUIDs: string[],
    seconds: number,
    allowDuplicates?: boolean,
    options?: ScanOptions
  ): Promise<void>;
  export function stopScan(): Promise<void>;
  export function connect(peripheralID: string): Promise<void>;
  export function disconnect(
    peripheralID: string,
    force?: boolean
  ): Promise<void>;

  export function checkState(): void;

  export function startNotification(
    peripheralID: string,
    serviceUUID: string,
    characteristicUUID: string
  ): Promise<void>;

  // [android only]
  export function startNotificationUseBuffer(
    peripheralID: string,
    serviceUUID: string,
    characteristicUUID: string,
    buffer: number
  ): Promise<void>;

  export function stopNotification(
    peripheralID: string,
    serviceUUID: string,
    characteristicUUID: string
  ): Promise<void>;

  export function read(
    peripheralID: string,
    serviceUUID: string,
    characteristicUUID: string
  ): Promise<any>;

  export function write(
    peripheralID: string,
    serviceUUID: string,
    characteristicUUID: string,
    data: any,
    maxByteSize?: number
  ): Promise<void>;

  export function writeWithoutResponse(
    peripheralID: string,
    serviceUUID: string,
    characteristicUUID: string,
    data: any,
    maxByteSize?: number,
    queueSleepTime?: number
  ): Promise<void>;

  export function readRSSI(peripheralID: string): Promise<number>;

  export function getConnectedPeripherals(
    serviceUUIDs: string[]
  ): Promise<Peripheral[]>;

  export function getDiscoveredPeripherals(): Promise<Peripheral[]>;

  export function isPeripheralConnected(
    peripheralID: string,
    serviceUUIDs: string[]
  ): Promise<boolean>;

  // [Android only API 21+]
  export enum ConnectionPriority {
    balanced = 0,
    high = 1,
    low = 2,
  }

  // [Android only 21+]
  export function requestConnectionPriority(
    peripheralID: string,
    connectionPriority: ConnectionPriority
  ): Promise<boolean>;

  // [Android only]
  export function enableBluetooth(): Promise<void>;

  // [Android only]
  export function refreshCache(peripheralID: string): Promise<void>;

  // [Android only API 21+]
  export function requestMTU(peripheralID: string, mtu: number): Promise<number>;

  export function createBond(
    peripheralID: string,
    peripheralPin?: string
  ): Promise<void>;

  export function removeBond(peripheralID: string): Promise<void>;

  export function getBondedPeripherals(): Promise<Peripheral[]>;

  export function removePeripheral(peripheralID: string): Promise<void>;

  // [Android only]
  export function setName(name: string): void;

  export interface Service {
    uuid: string;
  }

  export interface Descriptor {
    value: string;
    uuid: string;
  }

  export interface Characteristic {
    // See https://developer.apple.com/documentation/corebluetooth/cbcharacteristicproperties
    properties: {
      Broadcast?: "Broadcast";
      Read?: "Read";
      WriteWithoutResponse?: "WriteWithoutResponse";
      Write?: "Write";
      Notify?: "Notify";
      Indicate?: "Indicate";
      AuthenticatedSignedWrites?: "AuthenticatedSignedWrites";
      ExtendedProperties?: "ExtendedProperties";
      NotifyEncryptionRequired?: "NotifyEncryptionRequired";
      IndicateEncryptionRequired?: "IndicateEncryptionRequired";
    }
    characteristic: string;
    service: string;
    descriptors?: Descriptor[];

  }

  export interface PeripheralInfo extends Peripheral {
    serviceUUIDs?: string[];
    characteristics?: Characteristic[];
    services?: Service[];
  }

  export function retrieveServices(
    peripheralID: string,
    serviceUUIDs?: string[]
  ): Promise<PeripheralInfo>;

  export enum BleEventType {
    BleManagerDidUpdateState = 'BleManagerDidUpdateState',
    BleManagerStopScan = 'BleManagerStopScan',
    BleManagerDiscoverPeripheral = 'BleManagerDiscoverPeripheral',
    BleManagerDidUpdateValueForCharacteristic = 'BleManagerDidUpdateValueForCharacteristic',
    BleManagerConnectPeripheral = 'BleManagerConnectPeripheral',
    BleManagerDisconnectPeripheral = 'BleManagerDisconnectPeripheral',
    BleManagerPeripheralDidBond = 'BleManagerPeripheralDidBond', // [Android only]
    BleManagerCentralManagerWillRestoreState = 'BleManagerCentralManagerWillRestoreState', // [iOS only]
    BleManagerDidUpdateNotificationStateFor = 'BleManagerDidUpdateNotificationStateFor', // [iOS only]
  }

  export interface BleStopScanEvent {
    status?: number; // [iOS only]
  }

  export interface BleManagerDidUpdateStateEvent {
    state: BleState;
  }

  export interface BleConnectPeripheralEvent {
    readonly peripheral: string; // peripheral id
    readonly status?: number; // [android only]
  }

  export type BleDiscoverPeripheralEvent = Peripheral;

  // [Android only]
  export type BleBondedPeripheralEvent = Peripheral;

  export interface BleDisconnectPeripheralEvent {
    readonly peripheral: string; // peripheral id
    readonly status?: number; // [android only] disconnect reason.
    readonly domain?: string; // [iOS only] disconnect error domain.
    readonly code?: number; // [iOS only] disconnect error code.
  }

  export interface BleManagerDidUpdateValueForCharacteristicEvent {
    readonly characteristic: string; // characteristic UUID
    readonly peripheral: string; // peripheral id
    readonly service: string; // service UUID
    readonly value: Uint8Array;
  }

  // [iOS only]
  export interface BleManagerDidUpdateNotificationStateForEvent {
    readonly peripheral: string; // peripheral id
    readonly characteristic: string; // characteristic UUID
    readonly isNotifying: boolean; // is the characteristic notifying or not
    readonly domain: string; // error domain.
    readonly code: number; // error code.
  }
}
