declare module "react-native-ble-manager" {
  export interface Peripheral {
    id: string;
    rssi: number;
    name?: string;
    advertising: AdvertisingData;
  }

  export interface AdvertisingData {
    isConnectable?: boolean;
    localName?: string;
    manufacturerData?: any;
    serviceUUIDs?: string[];
    txPowerLevel?: number;
  }

  export interface StartOptions {
    showAlert?: boolean;
    restoreIdentifierKey?: string;
    queueIdentifierKey?: string;
    forceLegacy?: boolean;
  }

  export function start(options?: StartOptions): Promise<void>;

  export interface ScanOptions {
    numberOfMatches?: number;
    matchMode?: number;
    scanMode?: number;
    reportDelay?: number;
    phy?: number;
    legacy?: boolean;
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

  /// Android only
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

  export function readRSSI(peripheralID: string): Promise<void>;

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
  export function requestConnectionPriority(
    peripheralID: string,
    connectionPriority: ConnectionPriority
  ): Promise<void>;
  /// Android only
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
}
