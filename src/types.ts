export interface Peripheral {
  /**
   * the id of the peripheral
   */
  id: string;
  /**
   * the RSSI value
   */
  rssi: number;
  /**
   * the name of the peripheral
   */
  name?: string;
  /**
   * the advertising payload
   */
  advertising: AdvertisingData;
}

export interface AdvertisingData {
  isConnectable?: boolean;
  localName?: string;
  /**
   * contains the raw bytes and data (Base64 encoded string)
   */
  manufacturerData?: string;
  serviceUUIDs?: string[];
  txPowerLevel?: number;
}

export interface StartOptions {
  showAlert?: boolean;
  restoreIdentifierKey?: string;
  queueIdentifierKey?: string;
  forceLegacy?: boolean;
}

export interface ScanOptions {
  numberOfMatches?: number;
  matchMode?: number;
  scanMode?: number;
  reportDelay?: number;
}

export enum BleErrorCode {
  NotSupported = 1,
  NoBluetoothSupport = 2,
  UserRefusedEnable = 4,
  CurrentActivityUnavailable = 6,
  InvalidPeripheralUuid = 8,
  MaxBondRequestsReached = 10,
  CreateBondFailed = 12,
  RemoveBondFailed = 14,
  PeripheralNotFound = 16,
  ServiceUuidOrCharacteristicUuidMissing = 18,
  BondRequestDenied = 20,
  IllegalRemoveWhileConnected = 22,
  WriteDescriptorFailed = 24,
  MissingNotifyOrIndicateFlag = 26,
  SetNotificationFailed = 28,
  CharacteristicNotFound = 30,
  PeripheralNotConnected = 32,
  GattIsNull = 34,
  PeripheralDisconnected = 36,
  ConnectionError = 38,
  InvalidAdkVersion = 40,
  ReadFailed = 42,
  RssiReadFailed = 44,
  CacheRefreshFailed = 46,
  UnknownException = 48,
  WriteFailed = 50,
  WriteInterrupted = 52,
}

export enum IOSErrorCode {
  Unknown = 0,
  InvalidParameters = 1,
  InvalidHandle = 2,
  PeripheralNotConnected = 3,
  OutOfSpace = 4,
  OperationCancelled = 5,
  ConnectionTimeout = 6,
  PeripheralDisconnected = 7,
  UuidNotAllowed = 8,
  AlreadyAdvertising = 9,
  ConnectionFailed = 10,
  ConnectionLimitReached = 11,
  UnknownDevice = 12,
  OperationNotSupported = 13,
}

export enum AttCode {
  Success = 0,
  InvalidHandle = 1,
  ReadNotPermitted = 2,
  WriteNotPermitted = 3,
  InvalidPdu = 4,
  InsufficientAuthentication = 5,
  RequestNotSupported = 6,
  InvalidOffset = 7,
  InsufficientAuthorization = 8,
  PrepareQueueFull = 9,
  AttributeNotFound = 10,
  AttributeNotLong = 11,
  InsufficientEncryptionKeySize = 12,
  InvalidAttributeValueLength = 13,
  UnlikelyError = 14,
  InsufficientEncryption = 15,
  UnsupportedGroupType = 16,
  InsufficientResources = 17,
  ConnectionCongested = 143,
  Failure = 257,
}

/**
 * [Android only API 21+]
 */
export enum ConnectionPriority {
  balanced = 0,
  high = 1,
  low = 2,
}

export type Service = string | { uuid: string };

export interface Descriptor {
  value: string;
  uuid: string;
}

export type Properties =
  | 'Broadcast'
  | 'Read'
  | 'WriteWithoutResponse'
  | 'Write'
  | 'Notify'
  | 'Indicate'
  | 'AuthenticatedSignedWrites'
  | 'ExtendedProperties'
  | 'NotifyEncryptionRequired'
  | 'IndicateEncryptionRequired';

export interface Characteristic {
  // See https://developer.apple.com/documentation/corebluetooth/cbcharacteristicproperties
  properties:
    | {
        [key in Properties]: key;
      }
    | Properties[];
  characteristic: string;
  service: string;
  descriptors?: Descriptor[];
}

export interface PeripheralInfo extends Peripheral {
  serviceUUIDs?: string[];
  characteristics?: Characteristic[];
  services?: Service[];
}
