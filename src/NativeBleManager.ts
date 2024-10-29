import type { TurboModule } from 'react-native/Libraries/TurboModule/RCTExport';
import { TurboModuleRegistry } from 'react-native';
import {BleState, ConnectOptions, Peripheral, PeripheralInfo, ScanOptions, StartOptions} from "./types";

export interface Spec extends TurboModule {
    start(options: StartOptions, callback: (error: string|null) => void): void;

    scan(
        serviceUUIDStrings: string[],
        timeoutSeconds: number,
        allowDuplicates: boolean,
        scanningOptions: ScanOptions,
        callback: (error: string|null) => void
    ): void;


    stopScan(callback: (error: string|null) => void): void;

    connect(
        peripheralUUID: string,
        options: ConnectOptions,
        callback: (error: string|null) => void
    ): void;

    disconnect(
        peripheralUUID: string,
        force: boolean,
        callback: (error: string|null) => void
    ): void;

    retrieveServices(
        peripheralUUID: string,
        services: string[],
        callback: (error: string|null, peripheral: PeripheralInfo) => void
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

    getDiscoveredPeripherals(callback: (error: string | null, result: Peripheral[] | null) => void): void;

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

    getBondedPeripherals(callback: (error: string | null, result: Peripheral[] | null) => void): void;

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

    setName(
        name: string
    ): void;

    getAssociatedPeripherals(callback: (error: string | null, peripherals: Peripheral[] | null) => void): void;

    removeAssociatedPeripheral(
        peripheralUUID: string,
        callback: (error: string | null) => void
    ): void;

    supportsCompanion(callback: (supports: boolean) => void): void;

    companionScan(
        serviceUUIDs: string[],
        callback: (error: string | null, peripheral: Peripheral | null) => void
    ): void;
}

export default TurboModuleRegistry.get<Spec>('BleManager') as Spec | null;
