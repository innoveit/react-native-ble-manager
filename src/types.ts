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

export interface UpdateStateInfo {
  /**
   * the new BLE state
   */
  state: 'on' | 'off';
}
export interface CharacteristicValueUpdate {
  /**
   * the read value
   */
  value: number[];
  /**
   * the id of the peripheral
   */
  peripheral: string;
  /**
   * the UUID of the characteristic
   */
  characteristic: string;
  /**
   *  the UUID of the characteristic
   */
  service: string;
}

export interface ConnectPeripheralInfo {
  /**
   * the id of the peripheral
   */
  peripheral: string;
  /**
   * [Android only] connect [`reasons`](https://developer.android.com/reference/android/bluetooth/BluetoothGattCallback.html#onConnectionStateChange(android.bluetooth.BluetoothGatt,%20int,%20int))
   */
  status?: number;
}

export interface CentralManagerWillRestoreStateInfo {
  /**
   * [iOS only] an array of previously connected peripherals.
   */
  peripherals: Peripheral[];
}