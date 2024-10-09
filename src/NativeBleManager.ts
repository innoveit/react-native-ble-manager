import type { TurboModule } from 'react-native/Libraries/TurboModule/RCTExport';
import { TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
    start(options: Record<string, any>, callback: (response: any) => void): void;

    scan(
        serviceUUIDStrings: string[],
        timeoutSeconds: number,
        allowDuplicates: boolean,
        scanningOptions: Record<string, any>,
        callback: (response: any) => void
    ): void;

    stopScan(callback: (response: any) => void): void;

    connect(
        peripheralUUID: string,
        options: Record<string, any>,
        callback: (response: any) => void
    ): void;

    disconnect(
        peripheralUUID: string,
        force: boolean,
        callback: (response: any) => void
    ): void;

    retrieveServices(
        peripheralUUID: string,
        services: string[],
        callback: (response: any) => void
    ): void;

    readRSSI(
        peripheralUUID: string,
        callback: (response: any) => void
    ): void;

    readDescriptor(
        peripheralUUID: string,
        serviceUUID: string,
        characteristicUUID: string,
        descriptorUUID: string,
        callback: (response: any) => void
    ): void;

    writeDescriptor(
        peripheralUUID: string,
        serviceUUID: string,
        characteristicUUID: string,
        descriptorUUID: string,
        message: any[],
        callback: (response: any) => void
    ): void;

    getDiscoveredPeripherals(callback: (response: any) => void): void;

    checkState(callback: (response: any) => void): void;

    write(
        peripheralUUID: string,
        serviceUUID: string,
        characteristicUUID: string,
        message: any[],
        maxByteSize: number,
        callback: (response: any) => void
    ): void;

    writeWithoutResponse(
        peripheralUUID: string,
        serviceUUID: string,
        characteristicUUID: string,
        message: any[],
        maxByteSize: number,
        queueSleepTime: number,
        callback: (response: any) => void
    ): void;

    read(
        peripheralUUID: string,
        serviceUUID: string,
        characteristicUUID: string,
        callback: (response: any) => void
    ): void;

    startNotification(
        peripheralUUID: string,
        serviceUUID: string,
        characteristicUUID: string,
        callback: (response: any) => void
    ): void;

    stopNotification(
        peripheralUUID: string,
        serviceUUID: string,
        characteristicUUID: string,
        callback: (response: any) => void
    ): void;

    getConnectedPeripherals(
        serviceUUIDStrings: string[],
        callback: (response: any) => void
    ): void;

    isPeripheralConnected(
        peripheralUUID: string,
        callback: (response: any) => void
    ): void;

    isScanning(callback: (response: any) => void): void;

    getMaximumWriteValueLengthForWithoutResponse(
        peripheralUUID: string,
        callback: (response: any) => void
    ): void;

    getMaximumWriteValueLengthForWithResponse(
        deviceUUID: string,
        callback: (response: any) => void
    ): void;

    enableBluetooth(callback: (response: any) => void): void;

    getBondedPeripherals(callback: (response: any) => void): void;

    createBond(
        peripheralUUID: string,
        devicePin: string,
        callback: (response: any) => void
    ): void;

    removeBond(
        peripheralUUID: string,
        callback: (response: any) => void
    ): void;

    removePeripheral(
        peripheralUUID: string,
        callback: (response: any) => void
    ): void;

    requestMTU(
        peripheralUUID: string,
        mtu: number,
        callback: (response: any) => void
    ): void;

    requestConnectionPriority(
        peripheralUUID: string,
        connectionPriority: number,
        callback: (response: any) => void
    ): void;

    refreshCache(
        peripheralUUID: string,
        callback: (response: any) => void
    ): void;

    setName(
        name: string,
        callback: (response: any) => void
    ): void;

    getAssociatedPeripherals(callback: (response: any) => void): void;

    removeAssociatedPeripheral(
        peripheralUUID: string,
        callback: (response: any) => void
    ): void;

    supportsCompanion(callback: (response: any) => void): void;

    companionScan(
        serviceUUIDs: string[],
        callback: (response: any) => void
    ): void;
}

export default TurboModuleRegistry.get<Spec>('BleManager') as Spec | null;
