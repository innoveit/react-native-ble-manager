import { BleErrorCode } from "./types";

function isObject(o: unknown): o is Record<string, unknown> {
  return typeof o === "object" && o != null && !Array.isArray(o);
}

function isValidError(o: Record<string, unknown>): o is {
  message: string;
  iosCode?: number | null;
  iosDomain?: string | null;
  attErrorCode?: number | null;
  minAdkVersion?: number | null;
  customCode?: number | null;
  peripheralUUID?: string | null;
  serviceUUID?: string | null;
  characteristicUUID?: string | null;
  descriptorUUID?: string | null;
} {
  const { message, iosCode, iosDomain, attErrorCode, minAdkVersion, customCode, peripheralUUID, serviceUUID, characteristicUUID, descriptorUUID } = o;
  return (
    typeof message === "string" &&
    (iosCode == null || typeof iosCode === "number") &&
    (iosDomain == null || typeof iosDomain === "string") &&
    (attErrorCode == null || typeof attErrorCode === "number") &&
    (minAdkVersion == null || typeof minAdkVersion === "number") &&
    (customCode == null || typeof customCode === "number") &&
    (peripheralUUID == null || typeof peripheralUUID === "string") &&
    (serviceUUID == null || typeof serviceUUID === "string") &&
    (characteristicUUID == null || typeof characteristicUUID === "string") &&
    (descriptorUUID == null || typeof descriptorUUID === "string")
  );
}

export default class BleError extends Error {
  raw: unknown;
  iosCode: number | null;
  iosDomain: string | null;
  attErrorCode: number | null;
  minAdkVersion: number | null;
  customCode: BleErrorCode | number | null;
  peripheralUUID: string | null;
  serviceUUID: string | null;
  characteristicUUID: string | null;
  descriptorUUID: string | null;

  constructor(err: unknown) {
    if (typeof err === "string") {
      super(err);
      this.name = `${this.name}(RAW_STRING_ERROR)`;
      this.raw = err;
      this.iosCode = null;
      this.iosDomain = null;
      this.attErrorCode = null;
      this.minAdkVersion = null;
      this.customCode = null;
      this.peripheralUUID = null;
      this.serviceUUID = null;
      this.characteristicUUID = null;
      this.descriptorUUID = null;
    } else if (!isObject(err)) {
      super();
      this.name = `${this.name}(NON_OBJECT_ERROR)`;
      this.raw = err;
      this.iosCode = null;
      this.iosDomain = null;
      this.attErrorCode = null;
      this.minAdkVersion = null;
      this.customCode = null;
      this.peripheralUUID = null;
      this.serviceUUID = null;
      this.characteristicUUID = null;
      this.descriptorUUID = null;
    } else if (!isValidError(err)) {
      const maybeMessage = err.message;
      if (typeof maybeMessage === 'string') {
        super(maybeMessage);
      } else {
        super();
      }
      this.name = `${this.name}(INVALID_OBJECT_ERROR)`;
      this.raw = err;
      this.iosCode = null;
      this.iosDomain = null;
      this.attErrorCode = null;
      this.minAdkVersion = null;
      this.customCode = null;
      this.peripheralUUID = null;
      this.serviceUUID = null;
      this.characteristicUUID = null;
      this.descriptorUUID = null;
    } else {
      super(err.message);
      Object.defineProperty(this, 'raw', {
        value: err,
        enumerable: false,
      });
      if (err.iosDomain) {
        this.name = `${this.name}(${err.iosDomain})`;
      }
      const {iosCode, iosDomain, attErrorCode, minAdkVersion, customCode, peripheralUUID, serviceUUID, characteristicUUID, descriptorUUID } = err;
      this.iosCode = iosCode ?? null;
      this.iosDomain = iosDomain ?? null;
      this.attErrorCode = attErrorCode ?? null;
      this.minAdkVersion = minAdkVersion ?? null;
      this.customCode = customCode ?? null;
      this.peripheralUUID = peripheralUUID ?? null;
      this.serviceUUID = serviceUUID ?? null;
      this.characteristicUUID = characteristicUUID ?? null;
      this.descriptorUUID = descriptorUUID ?? null;
    }
  }
}
BleError.prototype.name = BleError.name;
