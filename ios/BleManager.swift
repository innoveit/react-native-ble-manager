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
    private var writeQueue: NSMutableArray
    private var notificationCallbacks: Dictionary<String, [RCTResponseSenderBlock]>
    private var stopNotificationCallbacks: Dictionary<String, [RCTResponseSenderBlock]>
    
    private var retrieveServicesLatches: Dictionary<String, Set<CBService>>
    private var characteristicsLatches: Dictionary<String, Set<CBCharacteristic>>
    
    private let serialQueue = DispatchQueue(label: "BleManager.serialQueue")
    
    private var exactAdvertisingName: [String]
    
    private var verboseLogging = false
    
    private override init() {
        peripherals = [:]
        connectCallbacks = [:]
        readCallbacks = [:]
        readRSSICallbacks = [:]
        readDescriptorCallbacks = [:]
        retrieveServicesCallbacks = [:]
        writeCallbacks = [:]
        writeQueue = NSMutableArray()
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
    
    @objc public func start(_ options: NSDictionary, 
                            callback: RCTResponseSenderBlock) {
        if verboseLogging {
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
        if Int(timeoutSeconds) > 0 {
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
        
        /*
         let ourReadCallbacks = readCallbacks.allKeys
         for key in ourReadCallbacks {
         if let keyString = key as? String, keyString.hasPrefix(peripheralUUIDString) {
         invokeAndClearDictionary(readCallbacks, withKey: key, usingParameters: [errorStr])
         }
         }
         
         let ourWriteCallbacks = writeCallbacks.allKeys
         for key in ourWriteCallbacks {
         if let keyString = key as? String, keyString.hasPrefix(peripheralUUIDString) {
         invokeAndClearDictionary(writeCallbacks, withKey: key, usingParameters: [errorStr])
         }
         }
         
         let ourNotificationCallbacks = notificationCallbacks.allKeys
         for key in ourNotificationCallbacks {
         if let keyString = key as? String, keyString.hasPrefix(peripheralUUIDString) {
         invokeAndClearDictionary(notificationCallbacks, withKey: key, usingParameters: [errorStr])
         }
         }
         
         let ourReadDescriptorCallbacks = readDescriptorCallbacks.allKeys
         for key in ourReadDescriptorCallbacks {
         if let keyString = key as? String, keyString.hasPrefix(peripheralUUIDString) {
         invokeAndClearDictionary(readDescriptorCallbacks, withKey: key, usingParameters: [errorStr])
         }
         }
         
         let ourStopNotificationsCallbacks = stopNotificationCallbacks.allKeys
         for key in ourStopNotificationsCallbacks {
         if let keyString = key as? String, keyString.hasPrefix(peripheralUUIDString) {
         invokeAndClearDictionary(stopNotificationCallbacks, withKey: key, usingParameters: [errorStr])
         }
         }*/
        
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
        if verboseLogging {
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
        if verboseLogging {
            NSLog("Services Discover")
        }
        
        var servicesForPeripheral = Set<CBService>()
        servicesForPeripheral.formUnion(peripheral.services ?? [])
        retrieveServicesLatches[peripheral.uuidAsString()!] = servicesForPeripheral
        
        if let services = peripheral.services {
            for service in services {
                if verboseLogging {
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
        if verboseLogging {
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
        
        if verboseLogging {
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
        if verboseLogging {
            print("didReadRSSI \(RSSI)")
        }
        
        if let error = error {
            invokeAndClearDictionary(&readRSSICallbacks, withKey: peripheral.uuidAsString(), usingParameters: [error.localizedDescription, RSSI])
        } else {
            invokeAndClearDictionary(&readRSSICallbacks, withKey: peripheral.uuidAsString(), usingParameters: [NSNull(), RSSI])
        }
    }
    
    static func getCentralManager() -> CBCentralManager? {
        return sharedManager
    }
    
    static func getInstance() -> BleManager? {
        return shared
    }
}
