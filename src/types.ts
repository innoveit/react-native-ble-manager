/**
 * android states: https://developer.android.com/reference/android/bluetooth/BluetoothAdapter#EXTRA_STATE
 * ios states: https://developer.apple.com/documentation/corebluetooth/cbcentralmanagerstate
 * */
export enum BleState {
  /**
   * [iOS only]
   */
  Unknown = 'unknown',
  /**
   * [iOS only]
   */
  Resetting = 'resetting',
  Unsupported = 'unsupported',
  /**
   * [iOS only]
   */
  Unauthorized = 'unauthorized',
  On = 'on',
  Off = 'off',
  /**
   * [android only]
   */
  TurningOn = 'turning_on',
  /**
   * [android only]
   */ 
  TurningOff = 'turning_off',
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
  CDVType: 'ArrayBuffer',
  /**
   * data as an array of numbers (which can be converted back to a Uint8Array (ByteArray),
   * using something like [Buffer.from()](https://github.com/feross/buffer))
   */
  bytes: number[],
  /**
   * base64-encoded string of the data
   */
  data: string
}

export interface StartOptions {
  /**
   * [iOS only]
   */
  showAlert?: boolean;
  /**
   * [iOS only]
   */
  restoreIdentifierKey?: string;
  /**
   * [iOS only]
   */
  queueIdentifierKey?: string;
  /**
   * [android only]
   */
  forceLegacy?: boolean;
}

/**
 * [android only]
 * https://developer.android.com/reference/android/bluetooth/le/ScanSettings
 */ 
export interface ScanOptions {
  /** 
   * This will only works if a ScanFilter is active. Otherwise, may not retrieve any result.
   * See https://developer.android.com/reference/android/bluetooth/le/ScanSettings#MATCH_NUM_FEW_ADVERTISEMENT. 
   * */
  numberOfMatches?: BleScanMatchCount;
  matchMode?: BleScanMatchMode;
  /** 
   * This will only works if a ScanFilter is active. Otherwise, may not retrieve any result.
   * See https://developer.android.com/reference/android/bluetooth/le/ScanSettings#CALLBACK_TYPE_FIRST_MATCH.
   * Also read [this issue](https://github.com/dariuszseweryn/RxAndroidBle/issues/561#issuecomment-532295346) for a deeper understanding 
   * of the very brittle stability of ScanSettings on android.
   * */
  callbackType?: BleScanCallbackType;
  scanMode?: BleScanMode;
  /**
   * This is supposed to push results after a certain delay.
   * In practice it is tricky, use with caution.
   * Do not set something below 5000ms as it will wait that long anyway before pushing the first results,
   * or on some phones it will ignore that setting and behave just like it was set to 0.
   * Set your minimum scan duration accordingly, otherwise you will not retrieve the batched results.
   * https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder#setReportDelay(long)
   */
  reportDelay?: number;
  /**
   * Does not work in conjunction with legacy scans. Setting an unsupported PHY will result in a failure to scan,
   * use with caution.
   * https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder#setPhy(int)
   */
  phy?: BleScanPhyMode;
  /**
   * true by default for compatibility with older apps. 
   * In that mode, scan will only retrieve advertisements data as specified by BLE 4.2 and below.
   * Change this if you want to benefit from the extended BLE 5 advertisement spec.
   * https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder#setLegacy(boolean)
   */
  legacy?: boolean;
  /**
   * an android ScanFilter, used if present to restrict scan results to devices with a specific advertising name.
   * This is a whole word match, not a partial search.
   * Use with caution, it's behavior is tricky and seems to be the following: 
   * if `callbackType` is set to `AllMatches`, only the completeLocalName will be used for filtering.
   * if `callbackType` is set to `FirstMatch`, the shortenedLocalName will be used for filtering.
   * https://developer.android.com/reference/android/bluetooth/le/ScanFilter.Builder#setDeviceName(java.lang.String)
   */
  exactAdvertisingName?: string;
}

/**
 * [android only]
 */
export enum BleScanMode {
  Opportunistic = -1,
  LowPower = 0,
  Balanced = 1,
  LowLatency = 2,
}

/**
 * [android only]
 */
export enum BleScanMatchMode {
  Aggressive = 1,
  Sticky = 2,
}

/**
 * [android only]
 */
export enum BleScanCallbackType {
  AllMatches = 1,
  FirstMatch = 2,
  MatchLost = 4,
}

/**
 * [android only]
 */
export enum BleScanMatchCount {
  OneAdvertisement = 1,
  FewAdvertisements = 2,
  MaxAdvertisements = 3,
}

/**
 * [android only]
 */
export enum BleScanPhyMode {
  LE_1M = 1,
  LE_2M = 2,
  LE_CODED = 3,
  ALL_SUPPORTED = 255,
}

/**
 * [android only API 21+]
 */
export enum ConnectionPriority {
  balanced = 0,
  high = 1,
  low = 2,
}

export interface Service {
  uuid: string;
}

export interface Descriptor {
  value: string;
  uuid: string;
}

export interface Characteristic {
  /**
   * See https://developer.apple.com/documentation/corebluetooth/cbcharacteristicproperties
   */
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

export enum BleEventType {
  BleManagerDidUpdateState = 'BleManagerDidUpdateState',
  BleManagerStopScan = 'BleManagerStopScan',
  BleManagerDiscoverPeripheral = 'BleManagerDiscoverPeripheral',
  BleManagerDidUpdateValueForCharacteristic = 'BleManagerDidUpdateValueForCharacteristic',
  BleManagerConnectPeripheral = 'BleManagerConnectPeripheral',
  BleManagerDisconnectPeripheral = 'BleManagerDisconnectPeripheral',
  /**
   * [Android only]
   */
  BleManagerPeripheralDidBond = 'BleManagerPeripheralDidBond',
  /**
   * [iOS only]
   */
  BleManagerCentralManagerWillRestoreState = 'BleManagerCentralManagerWillRestoreState',
  /**
   * [iOS only]
   */
  BleManagerDidUpdateNotificationStateFor = 'BleManagerDidUpdateNotificationStateFor',
}

export interface BleStopScanEvent {
  /**
   * [iOS only]
   */
  status?: number;
}

export interface BleManagerDidUpdateStateEvent {
  state: BleState;
}

export interface BleConnectPeripheralEvent {
  /**
   * peripheral id
   */
  readonly peripheral: string;
  /**
   * [android only]
   */
  readonly status?: number;
}

export type BleDiscoverPeripheralEvent = Peripheral;

/**
 * [Android only]
 */
export type BleBondedPeripheralEvent = Peripheral;

export interface BleDisconnectPeripheralEvent {
  /**
   * peripheral id
   */
  readonly peripheral: string;
  /**
   * [android only] disconnect reason.
   */
  readonly status?: number;
  /**
   * [iOS only] disconnect error domain.
   */
  readonly domain?: string;
  /**
   * [iOS only] disconnect error code.
   */
  readonly code?: number;
}

export interface BleManagerDidUpdateValueForCharacteristicEvent {
  /**
   * characteristic UUID
   */
  readonly characteristic: string;
  /**
   * peripheral id
   */
  readonly peripheral: string;
  /**
   * service UUID
   */
  readonly service: string;
  /**
   * data as an array of numbers (which can be converted back to a Uint8Array (ByteArray), 
   * using something like [Buffer.from()](https://github.com/feross/buffer))
   */
  readonly value: number[];
}

/**
 * [iOS only]
 */
export interface BleManagerDidUpdateNotificationStateForEvent {
  /**
   * peripheral id
   */
  readonly peripheral: string;
  /**
   * characteristic UUID
   */
  readonly characteristic: string;
  /**
   * is the characteristic notifying or not
   */
  readonly isNotifying: boolean;
  /**
   * error domain
   */
  readonly domain: string;
  /**
   * error code
   */
  readonly code: number;
}