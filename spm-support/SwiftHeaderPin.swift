// These imports replace the CocoaPods bridging header without changing shared sources.
@_exported import CoreBluetooth
@_exported import React
@_exported import RNBleManagerObjC

// Selector checks follow source renames; explicit Objective-C names still require review.
private let _swiftBleManagerBase: NSObject.Type = SwiftBleManager.self
private let _initializer: (BleManager) -> SwiftBleManager = SwiftBleManager.init(bleManager:)
private let _selectors: [Selector] = [
    #selector(SwiftBleManager.init(bleManager:)),
    #selector(SwiftBleManager.start(_:callback:)),
    #selector(SwiftBleManager.isStarted(_:)),
    #selector(SwiftBleManager.scan(_:callback:)),
    #selector(SwiftBleManager.stopScan(_:)),
    #selector(SwiftBleManager.connect(_:options:callback:)),
    #selector(SwiftBleManager.disconnect(_:force:callback:)),
    #selector(SwiftBleManager.retrieveServices(_:services:callback:)),
    #selector(SwiftBleManager.readRSSI(_:callback:)),
    #selector(SwiftBleManager.readDescriptor(_:serviceUUID:characteristicUUID:descriptorUUID:callback:)),
    #selector(SwiftBleManager.writeDescriptor(_:serviceUUID:characteristicUUID:descriptorUUID:message:callback:)),
    #selector(SwiftBleManager.getDiscoveredPeripherals(_:)),
    #selector(SwiftBleManager.getConnectedPeripherals(_:callback:)),
    #selector(SwiftBleManager.isPeripheralConnected(_:callback:)),
    #selector(SwiftBleManager.isScanning(_:)),
    #selector(SwiftBleManager.checkState(_:)),
    #selector(SwiftBleManager.write(_:serviceUUID:characteristicUUID:message:maxByteSize:callback:)),
    #selector(SwiftBleManager.writeWithoutResponse(_:serviceUUID:characteristicUUID:message:maxByteSize:queueSleepTime:callback:)),
    #selector(SwiftBleManager.read(_:serviceUUID:characteristicUUID:callback:)),
    #selector(SwiftBleManager.startNotificationWithBuffer(_:serviceUUID:characteristicUUID:bufferLength:callback:)),
    #selector(SwiftBleManager.startNotification(_:serviceUUID:characteristicUUID:callback:)),
    #selector(SwiftBleManager.stopNotification(_:serviceUUID:characteristicUUID:callback:)),
    #selector(SwiftBleManager.getMaximumWriteValueLengthForWithoutResponse(_:callback:)),
    #selector(SwiftBleManager.getMaximumWriteValueLengthForWithResponse(_:callback:)),
    #selector(SwiftBleManager.getCentralManager),
    #selector(SwiftBleManager.getInstance),
    #selector(SwiftBleManager.enableBluetooth(_:)),
    #selector(SwiftBleManager.getBondedPeripherals(_:)),
    #selector(SwiftBleManager.createBond(_:devicePin:callback:)),
    #selector(SwiftBleManager.removeBond(_:callback:)),
    #selector(SwiftBleManager.removePeripheral(_:callback:)),
    #selector(SwiftBleManager.requestMTU(_:mtu:callback:)),
    #selector(SwiftBleManager.requestConnectionPriority(_:connectionPriority:callback:)),
    #selector(SwiftBleManager.refreshCache(_:callback:)),
    #selector(SwiftBleManager.setName(_:)),
    #selector(SwiftBleManager.getAssociatedPeripherals(_:)),
    #selector(SwiftBleManager.removeAssociatedPeripheral(_:callback:)),
    #selector(SwiftBleManager.supportsCompanion(_:)),
    #selector(SwiftBleManager.companionScan(_:option:callback:)),
]

private let _start: (SwiftBleManager) -> ((NSDictionary, RCTResponseSenderBlock) -> Void) = SwiftBleManager.start(_:callback:)
private let _isStarted: (SwiftBleManager) -> ((RCTResponseSenderBlock) -> Void) = SwiftBleManager.isStarted(_:)
private let _scan: (SwiftBleManager) -> ((NSDictionary, RCTResponseSenderBlock) -> Void) = SwiftBleManager.scan(_:callback:)
private let _stopScan: (SwiftBleManager) -> ((@escaping RCTResponseSenderBlock) -> Void) = SwiftBleManager.stopScan(_:)
private let _connect: (SwiftBleManager) -> ((String, NSDictionary, @escaping RCTResponseSenderBlock) -> Void) = SwiftBleManager.connect(_:options:callback:)
private let _disconnect: (SwiftBleManager) -> ((String, Bool, @escaping RCTResponseSenderBlock) -> Void) = SwiftBleManager.disconnect(_:force:callback:)
private let _retrieveServices: (SwiftBleManager) -> ((String, [String], @escaping RCTResponseSenderBlock) -> Void) = SwiftBleManager.retrieveServices(_:services:callback:)
private let _readRSSI: (SwiftBleManager) -> ((String, @escaping RCTResponseSenderBlock) -> Void) = SwiftBleManager.readRSSI(_:callback:)
private let _readDescriptor: (SwiftBleManager) -> ((String, String, String, String, @escaping RCTResponseSenderBlock) -> Void) = SwiftBleManager.readDescriptor(_:serviceUUID:characteristicUUID:descriptorUUID:callback:)
private let _writeDescriptor: (SwiftBleManager) -> ((String, String, String, String, [UInt8], @escaping RCTResponseSenderBlock) -> Void) = SwiftBleManager.writeDescriptor(_:serviceUUID:characteristicUUID:descriptorUUID:message:callback:)
private let _getDiscoveredPeripherals: (SwiftBleManager) -> ((@escaping RCTResponseSenderBlock) -> Void) = SwiftBleManager.getDiscoveredPeripherals(_:)
private let _getConnectedPeripherals: (SwiftBleManager) -> (([String], @escaping RCTResponseSenderBlock) -> Void) = SwiftBleManager.getConnectedPeripherals(_:callback:)
private let _isPeripheralConnected: (SwiftBleManager) -> ((String, @escaping RCTResponseSenderBlock) -> Void) = SwiftBleManager.isPeripheralConnected(_:callback:)
private let _isScanning: (SwiftBleManager) -> ((@escaping RCTResponseSenderBlock) -> Void) = SwiftBleManager.isScanning(_:)
private let _checkState: (SwiftBleManager) -> ((@escaping RCTResponseSenderBlock) -> Void) = SwiftBleManager.checkState(_:)
private let _write: (SwiftBleManager) -> ((String, String, String, [UInt8], Int, @escaping RCTResponseSenderBlock) -> Void) = SwiftBleManager.write(_:serviceUUID:characteristicUUID:message:maxByteSize:callback:)
private let _writeWithoutResponse: (SwiftBleManager) -> ((String, String, String, [UInt8], Int, Int, @escaping RCTResponseSenderBlock) -> Void) = SwiftBleManager.writeWithoutResponse(_:serviceUUID:characteristicUUID:message:maxByteSize:queueSleepTime:callback:)
private let _read: (SwiftBleManager) -> ((String, String, String, @escaping RCTResponseSenderBlock) -> Void) = SwiftBleManager.read(_:serviceUUID:characteristicUUID:callback:)
private let _startNotificationWithBuffer: (SwiftBleManager) -> ((String, String, String, NSNumber, @escaping RCTResponseSenderBlock) -> Void) = SwiftBleManager.startNotificationWithBuffer(_:serviceUUID:characteristicUUID:bufferLength:callback:)
private let _startNotification: (SwiftBleManager) -> ((String, String, String, @escaping RCTResponseSenderBlock) -> Void) = SwiftBleManager.startNotification(_:serviceUUID:characteristicUUID:callback:)
private let _stopNotification: (SwiftBleManager) -> ((String, String, String, @escaping RCTResponseSenderBlock) -> Void) = SwiftBleManager.stopNotification(_:serviceUUID:characteristicUUID:callback:)
private let _getMaximumWriteValueLengthForWithoutResponse: (SwiftBleManager) -> ((String, @escaping RCTResponseSenderBlock) -> Void) = SwiftBleManager.getMaximumWriteValueLengthForWithoutResponse(_:callback:)
private let _getMaximumWriteValueLengthForWithResponse: (SwiftBleManager) -> ((String, @escaping RCTResponseSenderBlock) -> Void) = SwiftBleManager.getMaximumWriteValueLengthForWithResponse(_:callback:)
private let _getCentralManager: () -> CBCentralManager? = SwiftBleManager.getCentralManager
private let _getInstance: () -> SwiftBleManager? = SwiftBleManager.getInstance
private let _enableBluetooth: (SwiftBleManager) -> ((@escaping RCTResponseSenderBlock) -> Void) = SwiftBleManager.enableBluetooth(_:)
private let _getBondedPeripherals: (SwiftBleManager) -> ((@escaping RCTResponseSenderBlock) -> Void) = SwiftBleManager.getBondedPeripherals(_:)
private let _createBond: (SwiftBleManager) -> ((String, String, @escaping RCTResponseSenderBlock) -> Void) = SwiftBleManager.createBond(_:devicePin:callback:)
private let _removeBond: (SwiftBleManager) -> ((String, @escaping RCTResponseSenderBlock) -> Void) = SwiftBleManager.removeBond(_:callback:)
private let _removePeripheral: (SwiftBleManager) -> ((String, @escaping RCTResponseSenderBlock) -> Void) = SwiftBleManager.removePeripheral(_:callback:)
private let _requestMTU: (SwiftBleManager) -> ((String, Int, @escaping RCTResponseSenderBlock) -> Void) = SwiftBleManager.requestMTU(_:mtu:callback:)
private let _requestConnectionPriority: (SwiftBleManager) -> ((String, Int, @escaping RCTResponseSenderBlock) -> Void) = SwiftBleManager.requestConnectionPriority(_:connectionPriority:callback:)
private let _refreshCache: (SwiftBleManager) -> ((String, @escaping RCTResponseSenderBlock) -> Void) = SwiftBleManager.refreshCache(_:callback:)
private let _setName: (SwiftBleManager) -> ((String) -> Void) = SwiftBleManager.setName(_:)
private let _getAssociatedPeripherals: (SwiftBleManager) -> ((@escaping RCTResponseSenderBlock) -> Void) = SwiftBleManager.getAssociatedPeripherals(_:)
private let _removeAssociatedPeripheral: (SwiftBleManager) -> ((String, @escaping RCTResponseSenderBlock) -> Void) = SwiftBleManager.removeAssociatedPeripheral(_:callback:)
private let _supportsCompanion: (SwiftBleManager) -> ((@escaping RCTResponseSenderBlock) -> Void) = SwiftBleManager.supportsCompanion(_:)
private let _companionScan: (SwiftBleManager) -> (([Any], NSDictionary, RCTResponseSenderBlock) -> Void) = SwiftBleManager.companionScan(_:option:callback:)
