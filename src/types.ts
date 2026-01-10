/**
 * Android states: https://developer.android.com/reference/android/bluetooth/BluetoothAdapter#EXTRA_STATE
 * iOS states: https://developer.apple.com/documentation/corebluetooth/cbcentralmanagerstate
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
   * [Android only]
   */
  TurningOn = 'turning_on',
  /**
   * [Android only]
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
  rawData?: CustomAdvertisingData;
  manufacturerData?: Record<string, CustomAdvertisingData>;
  manufacturerRawData?: CustomAdvertisingData;
  serviceData?: Record<string, CustomAdvertisingData>;
  serviceUUIDs?: string[];
  txPowerLevel?: number;
}

export interface CustomAdvertisingData {
  CDVType: 'ArrayBuffer';
  /**
   * data as an array of numbers (which can be converted back to a Uint8Array (ByteArray),
   * using something like [Buffer.from()](https://github.com/feross/buffer))
   */
  bytes: number[];
  /**
   * base64-encoded string of the data
   */
  data: string;
}

export interface StartOptions {
  /**
   * [iOS only] Show or hide the alert if the bluetooth is turned off during initialization
   */
  showAlert?: boolean;
  /**
   * [iOS only] Unique key to use for CoreBluetooth state restoration
   */
  restoreIdentifierKey?: string;
  /**
   * [iOS only] Unique key to use for a queue identifier on which CoreBluetooth events will be dispatched
   */
  queueIdentifierKey?: string;
  /**
   * [Android only] Force to use the LegacyScanManager
   */
  forceLegacy?: boolean;
}

export interface ConnectOptions {
  /**
   * [Android only] whether to directly connect to the remote device (false) or to automatically connect as soon as the remote device becomes available (true) ([`Android doc`](<https://developer.android.com/reference/android/bluetooth/BluetoothDevice?hl=en#connectGatt(android.content.Context,%20boolean,%20android.bluetooth.BluetoothGattCallback,%20int,%20int)>))
   */
  autoconnect?: boolean;
  /**
   * [Android only] corresponding to the preferred phy channel ([`Android doc`](<https://developer.android.com/reference/android/bluetooth/BluetoothDevice?hl=en#connectGatt(android.content.Context,%20boolean,%20android.bluetooth.BluetoothGattCallback,%20int,%20int)>))
   */
  phy?: BleScanPhyMode;
}

/**
 * [Android only]
 * https://developer.android.com/reference/android/bluetooth/le/ScanSettings
 */
export interface ScanOptions {
  /**
   * The UUIDs of the services to look for.
   */
  serviceUUIDs?: string[];
  /**
   * The amount of seconds to scan. If not set or set to `0`, scans until `stopScan()` is called.
   */
  seconds?: number;
  /**
   * In Android this is a ScanFilter, if present it restricts scan results to devices with a specific advertising name.
   * This is a whole word match, not a partial search.
   * Use with caution, it's behavior is tricky and seems to be the following:
   * if `callbackType` is set to `AllMatches`, only the completeLocalName will be used for filtering.
   * if `callbackType` is set to `FirstMatch`, the shortenedLocalName will be used for filtering.
   * https://developer.android.com/reference/android/bluetooth/le/ScanFilter.Builder#setDeviceName(java.lang.String)
   * 
   * In iOS, this is a whole word match, not a partial search.
   */
  exactAdvertisingName?: string | string[];
  /**
   * [iOS only] whether to allow duplicate peripheral during a scan
   */
  allowDuplicates?: boolean;
  /**
   * [Android only] This will only work if a ScanFilter is active. Otherwise, may not retrieve any result.
   * See https://developer.android.com/reference/android/bluetooth/le/ScanSettings#MATCH_NUM_FEW_ADVERTISEMENT.
   * */
  numberOfMatches?: BleScanMatchCount;
  /**
   * [Android only] Defaults to `aggressive`.
   */
  matchMode?: BleScanMatchMode;
  /**
   * [Android only] This will only work if a ScanFilter is active. Otherwise, may not retrieve any result.
   * See https://developer.android.com/reference/android/bluetooth/le/ScanSettings#CALLBACK_TYPE_FIRST_MATCH.
   * Also read [this issue](https://github.com/dariuszseweryn/RxAndroidBle/issues/561#issuecomment-532295346) for a deeper understanding
   * of the very brittle stability of ScanSettings on Android. Defaults to `allMatches`. 
   * */
  callbackType?: BleScanCallbackType;
  /**
   * [Android only] Defaults to `lowPower`.
   */
  scanMode?: BleScanMode;
  /**
   * [Android only] This is supposed to push results after a certain delay.
   * In practice it is tricky, use with caution.
   * Do not set something below 5000ms as it will wait that long anyway before pushing the first results,
   * or on some phones it will ignore that setting and behave just like it was set to 0.
   * Set your minimum scan duration accordingly, otherwise you will not retrieve the batched results.
   * https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder#setReportDelay(long)
   */
  reportDelay?: number;
  /**
   * [Android only] Does not work in conjunction with legacy scans. Setting an unsupported PHY will result in a failure to scan,
   * use with caution.
   * https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder#setPhy(int)
   */
  phy?: BleScanPhyMode;
  /**
   * [Android only] true by default for compatibility with older apps.
   * In that mode, scan will only retrieve advertisements data as specified by BLE 4.2 and below.
   * Change this if you want to benefit from the extended BLE 5 advertisement spec.
   * https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder#setLegacy(boolean)
   */
  legacy?: boolean;
  /**
   * [Android only] Filters scan results by manufacturer id and data.
   * `manufacturerId` usually matches the company id, can be given as a hex, e.g. 0xe4f7.
   * `manufacturerData` and `manufacturerDataMask` must have the same length. For any bit in the mask, set it to 1 if
   * it needs to match the one in manufacturer data, otherwise set it to 0.
   * https://developer.android.com/reference/android/bluetooth/le/ScanFilter.Builder#setManufacturerData(int,%20byte[],%20byte[])
   */
  manufacturerData?: {
    manufacturerId: number;
    manufacturerData?: number[];
    manufacturerDataMask?: number[];
  };
  /**
   * [Android O+] Deliver scan results using a PendingIntent instead of the default callback.
   */
  useScanIntent?: boolean;
}

export interface CompanionScanOptions {
  /**
   * Scan only for a single peripheral. See Android's `AssociationRequest.Builder.setSingleDevice`.
   */
  single?: boolean;
}

/**
 * [Android only]
 */
export enum BleScanMode {
  Opportunistic = -1,
  LowPower = 0,
  Balanced = 1,
  LowLatency = 2,
}

/**
 * [Android only]
 */
export enum BleScanMatchMode {
  Aggressive = 1,
  Sticky = 2,
}

/**
 * [Android only]
 */
export enum BleScanCallbackType {
  AllMatches = 1,
  FirstMatch = 2,
  MatchLost = 4,
}

/**
 * [Android only]
 */
export enum BleScanMatchCount {
  OneAdvertisement = 1,
  FewAdvertisements = 2,
  MaxAdvertisements = 3,
}

/**
 * [Android only]
 */
export enum BleScanPhyMode {
  LE_1M = 1,
  LE_2M = 2,
  LE_CODED = 3,
  ALL_SUPPORTED = 255,
}

/**
 * [Android only API 21+]
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
    Broadcast?: 'Broadcast';
    Read?: 'Read';
    WriteWithoutResponse?: 'WriteWithoutResponse';
    Write?: 'Write';
    Notify?: 'Notify';
    Indicate?: 'Indicate';
    AuthenticatedSignedWrites?: 'AuthenticatedSignedWrites';
    ExtendedProperties?: 'ExtendedProperties';
    NotifyEncryptionRequired?: 'NotifyEncryptionRequired';
    IndicateEncryptionRequired?: 'IndicateEncryptionRequired';
  };
  characteristic: string;
  service: string;
  descriptors?: Descriptor[];
}

export interface PeripheralInfo extends Peripheral {
  serviceUUIDs?: string[];
  characteristics?: Characteristic[];
  services?: Service[];
}

export type EventCallback<T> = (event: T) => void | Promise<void>;

export interface BleStopScanEvent {
  /**
   * [iOS] The reason for stopping the scan. Error code 10 is used for timeouts, 0 covers everything else.
   * [Android] The reason for stopping the scan (<https://developer.android.com/reference/android/bluetooth/le/ScanCallback#constants_1>). Error code 10 is used for timeouts
   */
  status?: number;
}

export interface BleManagerDidUpdateStateEvent {
  /**
   * The new BLE state
   */
  state: BleState;
}

export interface BleConnectPeripheralEvent {
  /**
   * peripheral id
   */
  readonly peripheral: string;
  /**
   * [Android only]
   * 
   * Connect reason.
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
   * [Android only] disconnect reason.
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

/**
 * [iOS only]
 */
export interface BleManagerCentralManagerWillRestoreState {
  peripherals: Peripheral[];
}

/**
 * [Android only]
 *
 * Associate callback received a failure or failed to start the intent to
 * pick the device to associate.
 */
export type BleManagerCompanionFailure = { error: string };

/**
 * [Android only]
 *
 * User picked a device to associate with.
 *
 * Null if the request was cancelled by the user.
 */
export type BleManagerCompanionPeripheral = Peripheral | null;
