import type { TurboModule } from 'react-native/Libraries/TurboModule/RCTExport';
import { TurboModuleRegistry } from 'react-native';
import {UnsafeObject} from "react-native/Libraries/Types/CodegenTypes";

export interface Spec extends TurboModule {
    start(options: UnsafeObject, callback: (response: object) => void): void;

    scan(
        serviceUUIDStrings: string[],
        timeoutSeconds: number,
        allowDuplicates: boolean,
        scanningOptions: UnsafeObject,
        callback: (response: object) => void
    ): void;


    stopScan(callback: (response: object) => void): void;

    connect(
        peripheralUUID: string,
        options: UnsafeObject,
        callback: (response: object) => void
    ): void;

    disconnect(
        peripheralUUID: string,
        force: boolean,
        callback: (response: object) => void
    ): void;

    retrieveServices(
        peripheralUUID: string,
        services: string[],
        callback: (response: object) => void
    ): void;

    readRSSI(
        peripheralUUID: string,
        callback: (response: object) => void
    ): void;

    readDescriptor(
        peripheralUUID: string,
        serviceUUID: string,
        characteristicUUID: string,
        descriptorUUID: string,
        callback: (response: object) => void
    ): void;

    writeDescriptor(
        peripheralUUID: string,
        serviceUUID: string,
        characteristicUUID: string,
        descriptorUUID: string,
        message: object[],
        callback: (response: object) => void
    ): void;

    getDiscoveredPeripherals(callback: (response: object) => void): void;

    checkState(callback: (response: object) => void): void;

    write(
        peripheralUUID: string,
        serviceUUID: string,
        characteristicUUID: string,
        message: object[],
        maxByteSize: number,
        callback: (response: object) => void
    ): void;

    writeWithoutResponse(
        peripheralUUID: string,
        serviceUUID: string,
        characteristicUUID: string,
        message: object[],
        maxByteSize: number,
        queueSleepTime: number,
        callback: (response: object) => void
    ): void;

    read(
        peripheralUUID: string,
        serviceUUID: string,
        characteristicUUID: string,
        callback: (response: object) => void
    ): void;

    startNotification(
        peripheralUUID: string,
        serviceUUID: string,
        characteristicUUID: string,
        callback: (response: object) => void
    ): void;

    stopNotification(
        peripheralUUID: string,
        serviceUUID: string,
        characteristicUUID: string,
        callback: (response: object) => void
    ): void;

    getConnectedPeripherals(
        serviceUUIDStrings: string[],
        callback: (response: object) => void
    ): void;

    isPeripheralConnected(
        peripheralUUID: string,
        callback: (response: object) => void
    ): void;

    isScanning(callback: (response: object) => void): void;

    getMaximumWriteValueLengthForWithoutResponse(
        peripheralUUID: string,
        callback: (response: object) => void
    ): void;

    getMaximumWriteValueLengthForWithResponse(
        deviceUUID: string,
        callback: (response: object) => void
    ): void;

    enableBluetooth(callback: (response: object) => void): void;

    getBondedPeripherals(callback: (response: object) => void): void;

    createBond(
        peripheralUUID: string,
        devicePin: string,
        callback: (response: object) => void
    ): void;

    removeBond(
        peripheralUUID: string,
        callback: (response: object) => void
    ): void;

    removePeripheral(
        peripheralUUID: string,
        callback: (response: object) => void
    ): void;

    requestMTU(
        peripheralUUID: string,
        mtu: number,
        callback: (response: object) => void
    ): void;

    requestConnectionPriority(
        peripheralUUID: string,
        connectionPriority: number,
        callback: (response: object) => void
    ): void;

    refreshCache(
        peripheralUUID: string,
        callback: (response: object) => void
    ): void;

    setName(
        name: string,
        callback: (response: object) => void
    ): void;

    getAssociatedPeripherals(callback: (response: object) => void): void;

    removeAssociatedPeripheral(
        peripheralUUID: string,
        callback: (response: object) => void
    ): void;

    supportsCompanion(callback: (response: object) => void): void;

    companionScan(
        serviceUUIDs: string[],
        callback: (response: object) => void
    ): void;
}

export default TurboModuleRegistry.get<Spec>('BleManager') as Spec | null;
