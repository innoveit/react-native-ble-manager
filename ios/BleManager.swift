import Foundation
import CoreBluetooth


@objc(BleManager)
class BleManager: RCTEventEmitter, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    static var shared:BleManager?
    static var sharedManager:CBCentralManager?
    
    private var hasListeners:Bool = false
    
    private var manager: CBCentralManager?
    private var scanTimer: Timer?
    
    private var peripherals: Dictionary<String, Peripheral>
    private var connectCallbacks: Dictionary<String, [RCTResponseSenderBlock]>
    private var readCallbacks: Dictionary<String, [RCTResponseSenderBlock]>
    private var readRSSICallbacks: Dictionary<String, [RCTResponseSenderBlock]>
    private var readDescriptorCallbacks: Dictionary<String, [RCTResponseSenderBlock]>
    private var retrieveServicesCallbacks: Dictionary<String, [RCTResponseSenderBlock]>
    private var writeCallbacks: Dictionary<String, [RCTResponseSenderBlock]>
    private var writeQueue: Array<Any>
    private var notificationCallbacks: Dictionary<String, [RCTResponseSenderBlock]>
    private var stopNotificationCallbacks: Dictionary<String, [RCTResponseSenderBlock]>
    
    private var retrieveServicesLatches: Dictionary<String, Set<CBService>>
    private var characteristicsLatches: Dictionary<String, Set<CBCharacteristic>>
    
    private let serialQueue = DispatchQueue(label: "BleManager.serialQueue")
    
    private var exactAdvertisingName: [String]
    
    static var verboseLogging = false
    
    private override init() {
        peripherals = [:]
        connectCallbacks = [:]
        readCallbacks = [:]
        readRSSICallbacks = [:]
        readDescriptorCallbacks = [:]
        retrieveServicesCallbacks = [:]
        writeCallbacks = [:]
        writeQueue = []
        notificationCallbacks = [:]
        stopNotificationCallbacks = [:]
        retrieveServicesLatches = [:]
        characteristicsLatches = [:]
        exactAdvertisingName = []
        
        super.init()
        
        NSLog("BleManager created");
        
        BleManager.shared = self
        
        
        NotificationCenter.default.addObserver(self, selector: #selector(bridgeReloading), name: NSNotification.Name(rawValue: "RCTBridgeWillReloadNotification"), object: nil)
    }
    
    @objc override static func requiresMainQueueSetup() -> Bool { return true }
    
    @objc override func supportedEvents() -> [String]! {
        return ["BleManagerDidUpdateValueForCharacteristic", "BleManagerStopScan", "BleManagerDiscoverPeripheral", "BleManagerConnectPeripheral", "BleManagerDisconnectPeripheral", "BleManagerDidUpdateState", "BleManagerCentralManagerWillRestoreState", "BleManagerDidUpdateNotificationStateFor"]
    }
    
    @objc override func startObserving() {
        hasListeners = true
    }
    
    @objc override func stopObserving() {
        hasListeners = false
    }
    
    @objc func bridgeReloading() {
        if let manager = manager {
            if let scanTimer = self.scanTimer {
                scanTimer.invalidate()
                self.scanTimer = nil
                manager.stopScan()
            }
            
            manager.delegate = nil
        }
        
        serialQueue.sync {
            for p in peripherals.values {
                p.instance.delegate = nil
            }
        }
        
        peripherals = [:]
    }
    
    // Helper method to find a peripheral by UUID
    func findPeripheral(byUUID uuid: String) -> Peripheral? {
        var foundPeripheral: Peripheral? = nil
        
        serialQueue.sync {
            if let peripheral = peripherals[uuid] {
                foundPeripheral = peripheral;
            }
        }
        
        return foundPeripheral
    }
    
    // Helper method to insert callback in different queues
    func insertCallback(_ callback: @escaping RCTResponseSenderBlock, intoDictionary dictionary: inout Dictionary<String, [RCTResponseSenderBlock]>, withKey key: String) {
        serialQueue.sync {
            if var peripheralCallbacks = dictionary[key] {
                peripheralCallbacks.append(callback)
            } else {
                var peripheralCallbacks = [RCTResponseSenderBlock]()
                peripheralCallbacks.append(callback)
                dictionary[key] = peripheralCallbacks
            }
            
        }
    }
    
    // Helper method to call the callbacks for a specific peripheral and clear the queue
    func invokeAndClearDictionary(_ dictionary: inout Dictionary<String, [RCTResponseSenderBlock]>, withKey key: String, usingParameters parameters: [Any]) {
        serialQueue.sync {
            
            if let peripheralCallbacks = dictionary[key] {
                for callback in peripheralCallbacks {
                    callback(parameters)
                }
                
                dictionary.removeValue(forKey: key)
            }
        }
    }
    
    @objc func getContext(_ peripheralUUIDString: String, serviceUUIDString: String, characteristicUUIDString: String, prop: CBCharacteristicProperties, callback: @escaping RCTResponseSenderBlock) -> BLECommandContext? {
        let serviceUUID = CBUUID(string: serviceUUIDString)
        let characteristicUUID = CBUUID(string: characteristicUUIDString)
        
        guard let peripheral = peripherals[peripheralUUIDString] else {
            let error = String(format: "Could not find peripheral with UUID %@", peripheralUUIDString)
            NSLog(error)
            callback([error])
            return nil
        }
        
        guard let service = Helper.findService(fromUUID: serviceUUID, peripheral: peripheral.instance) else {
            let error = String(format: "Could not find service with UUID %@ on peripheral with UUID %@",
                               serviceUUIDString,
                               peripheral.instance.uuidAsString())
            NSLog(error)
            callback([error])
            return nil
        }
        
        var characteristic = Helper.findCharacteristic(fromUUID: characteristicUUID, service: service, prop: prop)
        
        // Special handling for INDICATE. If characteristic with notify is not found, check for indicate.
        if prop == CBCharacteristicProperties.notify && characteristic == nil {
            characteristic = Helper.findCharacteristic(fromUUID: characteristicUUID, service: service, prop: CBCharacteristicProperties.indicate)
        }
        
        // As a last resort, try to find ANY characteristic with this UUID, even if it doesn't have the correct properties
        if characteristic == nil {
            characteristic = Helper.findCharacteristic(fromUUID: characteristicUUID, service: service)
        }
        
        guard let finalCharacteristic = characteristic else {
            let error = String(format: "Could not find characteristic with UUID %@ on service with UUID %@ on peripheral with UUID %@",
                               characteristicUUIDString,
                               serviceUUIDString,
                               peripheral.instance.uuidAsString())
            NSLog(error)
            callback([error])
            return nil
        }
        
        let context = BLECommandContext()
        context.peripheral = peripheral
        context.service = service
        context.characteristic = finalCharacteristic
        return context
    }
    
    
    @objc public func start(_ options: NSDictionary,
                            callback: RCTResponseSenderBlock) {
        if BleManager.verboseLogging {
            NSLog("BleManager initialized")
        }
        var initOptions = [String: Any]()
        
        if let showAlert = options["showAlert"] as? Bool {
            initOptions[CBCentralManagerOptionShowPowerAlertKey] = showAlert
        }
        
        var queue: DispatchQueue
        if let queueIdentifierKey = options["queueIdentifierKey"] as? String {
            queue = DispatchQueue(label: queueIdentifierKey, qos: DispatchQoS.background)
        } else {
            queue = DispatchQueue.main
        }
        
        if let restoreIdentifierKey = options["restoreIdentifierKey"] as? String {
            initOptions[CBCentralManagerOptionRestoreIdentifierKey] = restoreIdentifierKey
            
            if let sharedManager = BleManager.sharedManager {
                manager = sharedManager
                manager?.delegate = self
            } else {
                manager = CBCentralManager(delegate: self, queue: queue, options: initOptions)
                BleManager.sharedManager = manager
            }
        } else {
            manager = CBCentralManager(delegate: self, queue: queue, options: initOptions)
            BleManager.sharedManager = manager
        }
        
        callback([])
    }
    
    @objc public func scan(_ serviceUUIDStrings: [Any],
                           timeoutSeconds: NSNumber,
                           allowDuplicates: Bool,
                           scanningOptions: NSDictionary,
                           callback:RCTResponseSenderBlock) {
        if Int(truncating: timeoutSeconds) > 0 {
            NSLog("scan with timeout \(timeoutSeconds)")
        } else {
            NSLog("scan")
        }
        
        // Clear the peripherals before scanning again, otherwise cannot connect again after disconnection
        // Only clear peripherals that are not connected - otherwise connections fail silently (without any
        // onDisconnect* callback).
        serialQueue.sync {
            let disconnectedPeripherals = peripherals.filter({ $0.value.instance.state != .connected && $0.value.instance.state != .connecting })
            disconnectedPeripherals.forEach { (uuid, peripheral) in
                peripheral.instance.delegate = nil
                peripherals.removeValue(forKey: uuid)
            }
        }
        
        var serviceUUIDs = [CBUUID]()
        if let serviceUUIDStrings = serviceUUIDStrings as? [String] {
            serviceUUIDs = serviceUUIDStrings.map { CBUUID(string: $0) }
        }
        
        var options: [String: Any]?
        if allowDuplicates {
            options = [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        }
        
        exactAdvertisingName.removeAll()
        if let names = scanningOptions["exactAdvertisingName"] as? [String] {
            exactAdvertisingName.append(contentsOf: names)
        }
        
        manager?.scanForPeripherals(withServices: serviceUUIDs, options: options)
        
        if timeoutSeconds.doubleValue > 0 {
            if let scanTimer = scanTimer {
                scanTimer.invalidate()
                self.scanTimer = nil
            }
            DispatchQueue.main.async {
                self.scanTimer = Timer.scheduledTimer(timeInterval: timeoutSeconds.doubleValue, target: self, selector: #selector(self.stopTimer), userInfo: nil, repeats: false)
            }
        }
        
        callback([])
    }
    
    @objc func stopTimer() {
        NSLog("Stop scan");
        scanTimer = nil;
        manager?.stopScan()
        if hasListeners {
            sendEvent(withName: "BleManagerStopScan", body: ["status": 10])
        }
    }
    
    
    @objc public func stopScan(_ callback: @escaping RCTResponseSenderBlock) {
        if let scanTimer = self.scanTimer {
            scanTimer.invalidate()
            self.scanTimer = nil
        }
        
        manager?.stopScan()
        
        if hasListeners {
            sendEvent(withName: "BleManagerStopScan", body: ["status": 0])
        }
        
        callback([])
    }
    
    
    @objc func connect(_ peripheralUUID: String,
                       options: NSDictionary,
                       callback: @escaping RCTResponseSenderBlock) {
        
        if let peripheral = peripherals[peripheralUUID] {
            // Found the peripheral, connect to it
            NSLog("Connecting to peripheral with UUID: \(peripheralUUID)")
            
            insertCallback(callback, intoDictionary: &connectCallbacks, withKey: peripheral.instance.uuidAsString())
            manager?.connect(peripheral.instance)
        } else {
            // Try to retrieve the peripheral
            NSLog("Retrieving peripheral with UUID: \(peripheralUUID)")
            
            if let uuid = UUID(uuidString: peripheralUUID) {
                let peripheralArray = manager?.retrievePeripherals(withIdentifiers: [uuid])
                if let retrievedPeripheral = peripheralArray?.first {
                    objc_sync_enter(peripherals)
                    peripherals[retrievedPeripheral.uuidAsString()] = Peripheral(peripheral:retrievedPeripheral)
                    objc_sync_exit(peripherals)
                    NSLog("Successfully retrieved and connecting to peripheral with UUID: \(peripheralUUID)")
                    
                    // Connect to the retrieved peripheral
                    insertCallback(callback, intoDictionary: &connectCallbacks, withKey: retrievedPeripheral.uuidAsString())
                    manager?.connect(retrievedPeripheral, options: nil)
                } else {
                    let error = "Could not find peripheral \(peripheralUUID)."
                    NSLog(error)
                    callback([error, NSNull()])
                }
            } else {
                let error = "Wrong UUID format \(peripheralUUID)"
                callback([error, NSNull()])
            }
        }
    }
    
    @objc func disconnect(_ peripheralUUID: String,
                          force: Bool,
                          callback: @escaping RCTResponseSenderBlock) {
        if let peripheral = peripherals[peripheralUUID] {
            NSLog("Disconnecting from peripheral with UUID: \(peripheralUUID)")
            
            if let services = peripheral.instance.services {
                for service in services {
                    if let characteristics = service.characteristics {
                        for characteristic in characteristics {
                            if characteristic.isNotifying {
                                NSLog("Remove notification from: \(characteristic.uuid)")
                                peripheral.instance.setNotifyValue(false, for: characteristic)
                            }
                        }
                    }
                }
            }
            
            manager?.cancelPeripheralConnection(peripheral.instance)
            callback([])
            
        } else {
            let error = "Could not find peripheral \(peripheralUUID)."
            NSLog(error)
            callback([error])
        }
    }
    
    @objc func retrieveServices(_ peripheralUUID: String,
                                services: [String],
                                callback: @escaping RCTResponseSenderBlock) {
        NSLog("retrieveServices \(services)")
        
        if let peripheral = peripherals[peripheralUUID], peripheral.instance.state == .connected {
            insertCallback(callback, intoDictionary: &retrieveServicesCallbacks, withKey: peripheral.instance.uuidAsString())
            
            var uuids: [CBUUID] = []
            for string in services {
                let uuid = CBUUID(string: string)
                uuids.append(uuid)
            }
            
            if !uuids.isEmpty {
                peripheral.instance.discoverServices(uuids)
            } else {
                peripheral.instance.discoverServices(nil)
            }
            
        } else {
            callback(["Peripheral not found or not connected"])
        }
    }
    
    @objc func readRSSI(_ peripheralUUID: String,
                        callback: @escaping RCTResponseSenderBlock) {
        NSLog("readRSSI")
        
        if let peripheral = peripherals[peripheralUUID], peripheral.instance.state == .connected {
            insertCallback(callback, intoDictionary: &readRSSICallbacks, withKey: peripheral.instance.uuidAsString())
            peripheral.instance.readRSSI()
        } else {
            callback(["Peripheral not found or not connected"])
        }
    }
    
    @objc func readDescriptor(_ peripheralUUID: String,
                              serviceUUID: String,
                              characteristicUUID: String,
                              descriptorUUID: String,
                              callback: @escaping RCTResponseSenderBlock) {
        NSLog("readDescriptor")
        
        guard let context = getContext(peripheralUUID, serviceUUIDString: serviceUUID, characteristicUUIDString: characteristicUUID, prop: CBCharacteristicProperties.read, callback: callback) else {
            return
        }
        
        let peripheral = context.peripheral
        let characteristic = context.characteristic
        
        guard let descriptor = Helper.findDescriptor(fromUUID: CBUUID(string: descriptorUUID), characteristic: characteristic!) else {
            let error = "Could not find descriptor with UUID \(descriptorUUID) on characteristic with UUID \(String(describing: characteristic?.uuid.uuidString)) on peripheral with UUID \(peripheralUUID)"
            NSLog(error)
            callback([error])
            return
        }
        
        if let peripheral = peripheral?.instance {
            let key = Helper.key(forPeripheral: peripheral, andCharacteristic: characteristic!, andDescriptor: descriptor)
            insertCallback(callback, intoDictionary: &readDescriptorCallbacks, withKey: key)
            
        }
        
        peripheral?.instance.readValue(for: descriptor)
    }
    
    @objc func getDiscoveredPeripherals(_ callback: @escaping RCTResponseSenderBlock) {
        NSLog("Get discovered peripherals")
        var discoveredPeripherals: [[String: Any]] = []
        
        serialQueue.sync {
            for (_, peripheral) in peripherals {
                discoveredPeripherals.append(peripheral.advertisingInfo())
            }
        }
        
        callback([NSNull(), discoveredPeripherals])
    }
    
    @objc func getConnectedPeripherals(_ serviceUUIDStrings: [String],
                                       callback: @escaping RCTResponseSenderBlock) {
        NSLog("Get connected peripherals")
        var serviceUUIDs: [CBUUID] = []
        
        for uuidString in serviceUUIDStrings {
            serviceUUIDs.append(CBUUID(string: uuidString))
        }
        
        var connectedPeripherals: [Peripheral] = []
        
        if serviceUUIDs.isEmpty {
            serialQueue.sync {
                connectedPeripherals = peripherals.filter({ $0.value.instance.state == .connected }).map({ p in
                    p.value
                })
            }
        } else {
            let connectedCBPeripherals: [CBPeripheral] = manager?.retrieveConnectedPeripherals(withServices: serviceUUIDs) ?? []
            
            serialQueue.sync {
                for ph in connectedCBPeripherals {
                    if let peripheral = peripherals[ph.uuidAsString()] {
                        connectedPeripherals.append(peripheral)
                    } else {
                        peripherals[ph.uuidAsString()] = Peripheral(peripheral: ph)
                    }
                }
            }
        }
        
        var foundedPeripherals: [[String: Any]] = []
        
        for peripheral in connectedPeripherals {
            foundedPeripherals.append(peripheral.advertisingInfo())
        }
        
        callback([NSNull(), foundedPeripherals])
    }
    
    @objc func checkState(_ callback: @escaping RCTResponseSenderBlock) {
        if let manager = manager {
            centralManagerDidUpdateState(manager)
            
            let stateName = Helper.centralManagerStateToString(manager.state)
            callback([stateName])
        }
    }
    
    @objc func write(_ peripheralUUID: String,
                     serviceUUID: String,
                     characteristicUUID: String,
                     message: [Any],
                     maxByteSize: Int,
                     callback: @escaping RCTResponseSenderBlock) {
        NSLog("write")
        
        guard let context = getContext(peripheralUUID, serviceUUIDString: serviceUUID, characteristicUUIDString: characteristicUUID, prop: CBCharacteristicProperties.write, callback: callback) else {
            return
        }
        
        let bytes = message.compactMap { ($0 as? NSNumber)?.intValue }
        let dataMessage = Data(bytes: bytes, count: bytes.count)
        
        if let peripheral = context.peripheral, let characteristic = context.characteristic {
            let key = Helper.key(forPeripheral:peripheral.instance, andCharacteristic: characteristic)
            insertCallback(callback, intoDictionary: &writeCallbacks, withKey: key)
            
            if BleManager.verboseLogging {
                NSLog("Message to write(\(dataMessage.count)): \(String(describing: dataMessage.hexadecimalString))")
            }
            
            if dataMessage.count > maxByteSize {
                var count = 0
                var offset = 0
                while count < dataMessage.count, (dataMessage.count - count) > maxByteSize {
                    let splitMessage = dataMessage.subdata(in: offset..<offset + maxByteSize)
                    writeQueue.append(splitMessage)
                    count += maxByteSize
                    offset += maxByteSize
                }
                
                if count < dataMessage.count {
                    let splitMessage = dataMessage.subdata(in: offset..<dataMessage.count)
                    writeQueue.append(splitMessage)
                }
                
                NSLog("Queued splitted message: \(writeQueue.count)")
                
                if case let firstMessage as Data = writeQueue.first {
                    peripheral.instance.writeValue(firstMessage, for: characteristic, type: .withResponse)
                }
            } else {
                peripheral.instance.writeValue(dataMessage, for: characteristic, type: .withResponse)
            }
        }
    }
    
    
    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        NSLog("Peripheral Connected: \(peripheral.uuidAsString() ?? "")")
        peripheral.delegate = self
        
        /*
         The state of the peripheral isn't necessarily updated until a small
         delay after didConnectPeripheral is called and in the meantime
         didFailToConnectPeripheral may be called
         */
        DispatchQueue.main.async {
            Timer.scheduledTimer(withTimeInterval: 0.002, repeats: false) { timer in
                // didFailToConnectPeripheral should have been called already if not connected by now
                self.invokeAndClearDictionary(&self.connectCallbacks, withKey: peripheral.uuidAsString(), usingParameters: [NSNull()])
                
                if self.hasListeners {
                    self.sendEvent(withName: "BleManagerConnectPeripheral", body: ["peripheral": peripheral.uuidAsString()])
                }
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        let errorStr = "Peripheral connection failure: \(peripheral.uuidAsString() ?? "") (\(error?.localizedDescription ?? "")"
        NSLog(errorStr)
        
        invokeAndClearDictionary(&connectCallbacks, withKey: peripheral.uuidAsString(), usingParameters: [errorStr])
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral:
                        CBPeripheral, error: Error?) {
        let peripheralUUIDString:String = peripheral.uuidAsString()
        NSLog("Peripheral Disconnected: \(peripheralUUIDString)")
        
        if let error = error {
            NSLog("Error: \(error)")
        }
        
        let errorStr = "Peripheral did disconnect: \(peripheralUUIDString)"
        
        invokeAndClearDictionary(&connectCallbacks, withKey: peripheralUUIDString, usingParameters: [errorStr])
        invokeAndClearDictionary(&readRSSICallbacks, withKey: peripheralUUIDString, usingParameters: [errorStr])
        invokeAndClearDictionary(&retrieveServicesCallbacks, withKey: peripheralUUIDString, usingParameters: [errorStr])
        
        
        for key in readCallbacks.keys {
            if let keyString = key as String?, keyString.hasPrefix(peripheralUUIDString) {
                invokeAndClearDictionary(&readCallbacks, withKey: key, usingParameters: [errorStr])
            }
        }
        
        for key in writeCallbacks.keys {
            if let keyString = key as String?, keyString.hasPrefix(peripheralUUIDString) {
                invokeAndClearDictionary(&writeCallbacks, withKey: key, usingParameters: [errorStr])
            }
        }
        
        for key in notificationCallbacks.keys {
            if let keyString = key as String?, keyString.hasPrefix(peripheralUUIDString) {
                invokeAndClearDictionary(&notificationCallbacks, withKey: key, usingParameters: [errorStr])
            }
        }
        
        for key in readDescriptorCallbacks.keys {
            if let keyString = key as String?, keyString.hasPrefix(peripheralUUIDString) {
                invokeAndClearDictionary(&readDescriptorCallbacks, withKey: key, usingParameters: [errorStr])
            }
        }
        
        for key in stopNotificationCallbacks.keys {
            if let keyString = key as String?, keyString.hasPrefix(peripheralUUIDString) {
                invokeAndClearDictionary(&stopNotificationCallbacks, withKey: key, usingParameters: [errorStr])
            }
        }
        
        if hasListeners {
            if let e:Error = error {
                sendEvent(withName: "BleManagerDisconnectPeripheral", body: ["peripheral": peripheralUUIDString, "domain": e._domain, "code": e._code, "description": e.localizedDescription])
            } else {
                sendEvent(withName: "BleManagerDisconnectPeripheral", body: ["peripheral": peripheralUUIDString])
            }
        }
    }
    
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let stateName = Helper.centralManagerStateToString(central.state)
        if hasListeners {
            sendEvent(withName: "BleManagerDidUpdateState", body: ["state": stateName])
        }
    }
    
    func handleDiscoveredPeripheral(_ peripheral: CBPeripheral,
                                    advertisementData: [String : Any],
                                    rssi : NSNumber) {
        if BleManager.verboseLogging {
            NSLog("Discover peripheral: \(peripheral.name ?? "NO NAME")");
        }
        
        var cp: Peripheral? = nil
        serialQueue.sync {
            if let p = peripherals[peripheral.uuidAsString()] {
                cp = p
                cp?.setRSSI(rssi)
                cp?.setAdvertisementData(advertisementData)
            } else {
                cp = Peripheral(peripheral:peripheral, rssi:rssi, advertisementData:advertisementData)
                peripherals[peripheral.uuidAsString()] = cp
            }
        }
        
        if (hasListeners) {
            sendEvent(withName: "BleManagerDiscoverPeripheral", body: cp?.advertisingInfo())
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        if exactAdvertisingName.count > 0 {
            if let peripheralName = peripheral.name {
                if exactAdvertisingName.contains(peripheralName) {
                    handleDiscoveredPeripheral(peripheral, advertisementData: advertisementData, rssi: RSSI)
                } else {
                    if let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
                        if exactAdvertisingName.contains(localName) {
                            handleDiscoveredPeripheral(peripheral, advertisementData: advertisementData, rssi: RSSI)
                        }
                    }
                }
            }
        } else {
            handleDiscoveredPeripheral(peripheral, advertisementData: advertisementData, rssi: RSSI)
        }
        
        
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        if let error = error {
            NSLog("Error: \(error)")
            return
        }
        if BleManager.verboseLogging {
            NSLog("Services Discover")
        }
        
        var servicesForPeripheral = Set<CBService>()
        servicesForPeripheral.formUnion(peripheral.services ?? [])
        retrieveServicesLatches[peripheral.uuidAsString()!] = servicesForPeripheral
        
        if let services = peripheral.services {
            for service in services {
                if BleManager.verboseLogging {
                    NSLog("Service \(service.uuid.uuidString) \(service.description)")
                }
                peripheral.discoverIncludedServices(nil, for: service) // discover included services
                peripheral.discoverCharacteristics(nil, for: service) // discover characteristics for service
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverIncludedServicesFor service: CBService,
                    error: Error?) {
        if let error = error {
            NSLog("Error: \(error)")
            return
        }
        peripheral.discoverCharacteristics(nil, for: service) // discover characteristics for included service
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        if let error = error {
            NSLog("Error: \(error)")
            return
        }
        if BleManager.verboseLogging {
            NSLog("Characteristics For Service Discover")
        }
        
        var characteristicsForService = Set<CBCharacteristic>()
        characteristicsForService.formUnion(service.characteristics ?? [])
        characteristicsLatches[service.uuid.uuidString] = characteristicsForService
        
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                peripheral.discoverDescriptors(for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverDescriptorsFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            NSLog("Error: \(error)")
            return
        }
        let peripheralUUIDString:String = peripheral.uuidAsString()
        let serviceUUIDString:String = (characteristic.service?.uuid.uuidString)!
        
        if BleManager.verboseLogging {
            NSLog("Descriptor For Characteristic Discover \(serviceUUIDString) \(characteristic.uuid.uuidString)")
        }
        
        if var servicesLatch = retrieveServicesLatches[peripheralUUIDString], var characteristicsLatch = characteristicsLatches[serviceUUIDString] {
            
            characteristicsLatch.remove(characteristic)
            characteristicsLatches[serviceUUIDString] = characteristicsLatch
            
            if characteristicsLatch.isEmpty {
                // All characteristics for this service have been checked
                servicesLatch.remove(characteristic.service!)
                retrieveServicesLatches[peripheralUUIDString] = servicesLatch
                
                if servicesLatch.isEmpty {
                    // All characteristics and services have been checked
                    if let peripheral = peripherals[peripheral.uuidAsString()] {
                        invokeAndClearDictionary(&retrieveServicesCallbacks, withKey: peripheralUUIDString, usingParameters: [NSNull(), peripheral.servicesInfo()])
                    }
                    characteristicsLatches.removeValue(forKey: serviceUUIDString)
                    retrieveServicesLatches.removeValue(forKey: peripheralUUIDString)
                }
            }
            
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didReadRSSI RSSI: NSNumber,
                    error: Error?) {
        if BleManager.verboseLogging {
            print("didReadRSSI \(RSSI)")
        }
        
        if let error = error {
            invokeAndClearDictionary(&readRSSICallbacks, withKey: peripheral.uuidAsString(), usingParameters: [error.localizedDescription, RSSI])
        } else {
            invokeAndClearDictionary(&readRSSICallbacks, withKey: peripheral.uuidAsString(), usingParameters: [NSNull(), RSSI])
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor descriptor: CBDescriptor,
                    error: Error?) {
        let key = Helper.key(forPeripheral: peripheral, andCharacteristic: descriptor.characteristic!, andDescriptor: descriptor)
        
        if let error = error {
            NSLog("Error reading descriptor value for \(descriptor.uuid) on characteristic \(descriptor.characteristic!.uuid) :\(error)")
            invokeAndClearDictionary(&readDescriptorCallbacks, withKey: key, usingParameters: [error, NSNull()])
            return
        }
        
        if let descriptorValue = descriptor.value as? Data {
            NSLog("Read value [descriptor: \(descriptor.uuid), characteristic: \(descriptor.characteristic!.uuid)]: (\(descriptorValue.count)) \(descriptorValue)")
        } else {
            NSLog("Read value [descriptor: \(descriptor.uuid), characteristic: \(descriptor.characteristic!.uuid)]: \(String(describing: descriptor.value))")
        }
        
        if readDescriptorCallbacks[key] != nil {
            if let descriptorValue = descriptor.value as? Data {
                invokeAndClearDictionary(&readDescriptorCallbacks, withKey: key, usingParameters: [NSNull(), descriptorValue.count > 0 ? descriptorValue : NSNull()])
            } else if let descriptorValue = descriptor.value as? NSNumber {
                let byteData = NSMutableData()
                var value = descriptorValue.uint64Value
                byteData.append(&value, length: MemoryLayout.size(ofValue: value))
                invokeAndClearDictionary(&readDescriptorCallbacks, withKey: key, usingParameters: [NSNull(), byteData.count > 0 ? byteData.toArray()! : NSNull()])
            } else if let descriptorValue = descriptor.value as? String {
                if let byteData = descriptorValue.data(using: .utf8) {
                    invokeAndClearDictionary(&readDescriptorCallbacks, withKey: key, usingParameters: [NSNull(), byteData.count > 0 ? byteData : NSNull()])
                }
            } else {
                NSLog("Unrecognized type of descriptor: (UUID: \(descriptor.uuid), value type: \(type(of: descriptor.value)), value: \(String(describing: descriptor.value)))")
                if let descriptorValue = descriptor.value as? Data {
                    invokeAndClearDictionary(&readDescriptorCallbacks, withKey: key, usingParameters: [NSNull(), descriptorValue.count > 0 ? descriptorValue : NSNull()])
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        let key = Helper.key(forPeripheral: peripheral, andCharacteristic: characteristic)
        
        if let error = error {
            NSLog("Error \(characteristic.uuid) :\(error)")
            invokeAndClearDictionary(&readCallbacks, withKey: key, usingParameters: [error, NSNull()])
            return
        }
        
        NSLog("Read value [\(characteristic.uuid)]: (\(characteristic.value?.count ?? 0)) \(characteristic.value ?? Data())")
        
        if readCallbacks[key] != nil {
            invokeAndClearDictionary(&readCallbacks, withKey: key, usingParameters: [NSNull(), characteristic.value!])
        } else {
            if hasListeners {
                sendEvent(withName: "BleManagerDidUpdateValueForCharacteristic", body: [
                    "peripheral": peripheral.uuidAsString,
                    "characteristic": characteristic.uuid.uuidString.lowercased(),
                    "service": characteristic.service?.uuid.uuidString.lowercased(),
                    "value": characteristic.value!.count > 0 ? characteristic.value : nil
                ])
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            NSLog("Error in didUpdateNotificationStateForCharacteristic: \(error)")
            
            if hasListeners {
                sendEvent(withName: "BleManagerDidUpdateNotificationStateFor", body: [
                    "peripheral": peripheral.uuidAsString,
                    "characteristic": characteristic.uuid.uuidString.lowercased(),
                    "isNotifying": false,
                    "domain": (error as NSError).domain,
                    "code": (error as NSError).code
                ])
            }
        }
        
        let key = Helper.key(forPeripheral: peripheral, andCharacteristic: characteristic)
        
        if characteristic.isNotifying {
            if notificationCallbacks[key] != nil {
                if let error = error {
                    invokeAndClearDictionary(&notificationCallbacks, withKey: key, usingParameters: [error])
                } else {
                    if BleManager.verboseLogging {
                        NSLog("Notification began on \(characteristic.uuid)")
                    }
                    invokeAndClearDictionary(&notificationCallbacks, withKey: key, usingParameters: [])
                }
            }
        } else {
            // Notification has stopped
            if stopNotificationCallbacks[key] != nil {
                if error != nil {
                    invokeAndClearDictionary(&stopNotificationCallbacks, withKey: key, usingParameters: [error as Any])
                } else {
                    if BleManager.verboseLogging {
                        NSLog("Notification ended on \(characteristic.uuid)")
                    }
                    invokeAndClearDictionary(&stopNotificationCallbacks, withKey: key, usingParameters: [])
                }
            }
        }
        if hasListeners {
            sendEvent(withName: "BleManagerDidUpdateNotificationStateFor", body: [
                "peripheral": peripheral.uuidAsString,
                "characteristic": characteristic.uuid.uuidString.lowercased(),
                "isNotifying": characteristic.isNotifying
            ])
        }
    }
    
    
    
    static func getCentralManager() -> CBCentralManager? {
        return sharedManager
    }
    
    static func getInstance() -> BleManager? {
        return shared
    }
}
