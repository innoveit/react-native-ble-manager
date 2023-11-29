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
    private var retrieveServicesLatches: NSMutableDictionary
    private var readCallbacks: Dictionary<String, [RCTResponseSenderBlock]>
    private var readRSSICallbacks: Dictionary<String, [RCTResponseSenderBlock]>
    private var readDescriptorCallbacks: Dictionary<String, [RCTResponseSenderBlock]>
    private var retrieveServicesCallbacks: Dictionary<String, [RCTResponseSenderBlock]>
    private var writeCallbacks: Dictionary<String, [RCTResponseSenderBlock]>
    private var writeQueue: NSMutableArray
    private var notificationCallbacks: Dictionary<String, [RCTResponseSenderBlock]>
    private var stopNotificationCallbacks: Dictionary<String, [RCTResponseSenderBlock]>
    
    private let serialQueue = DispatchQueue(label: "BleManager.serialQueue")
    
    private override init() {
        peripherals = [:]
        connectCallbacks = [:]
        retrieveServicesLatches = NSMutableDictionary()
        readCallbacks = [:]
        readRSSICallbacks = [:]
        readDescriptorCallbacks = [:]
        retrieveServicesCallbacks = [:]
        writeCallbacks = [:]
        writeQueue = NSMutableArray()
        notificationCallbacks = [:]
        stopNotificationCallbacks = [:]
        
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
        
        objc_sync_enter(peripherals)
        for p in peripherals.values {
            p.instance.delegate = nil
        }
        objc_sync_exit(peripherals)
        
        peripherals = [:]
    }
    
    // Helper method to find a peripheral by UUID
    func findPeripheral(byUUID uuid: String) -> Peripheral? {
        var foundPeripheral: Peripheral? = nil
        
        objc_sync_enter(peripherals)
        if let peripheral = peripherals[uuid] {
            foundPeripheral = peripheral;
        }
        objc_sync_exit(peripherals)
        
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
    
    @objc public func start(_ options: NSDictionary, callback: RCTResponseSenderBlock) {
        NSLog("BleManager initialized")
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
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let stateName = Helper.centralManagerStateToString(central.state)
        if hasListeners {
            sendEvent(withName: "BleManagerDidUpdateState", body: ["state": stateName])
        }
    }
    
    @objc public func scan(_ serviceUUIDStrings: [Any],
                           timeoutSeconds: NSNumber,
                           allowDuplicates: Bool,
                           scanningOptions: NSDictionary,
                           callback:RCTResponseSenderBlock) {
        NSLog("scan with timeout \(timeoutSeconds)")
        
        // Clear the peripherals before scanning again, otherwise cannot connect again after disconnection
        // Only clear peripherals that are not connected - otherwise connections fail silently (without any
        // onDisconnect* callback).
        objc_sync_enter(peripherals)
        let disconnectedPeripherals = peripherals.filter({ $0.value.instance.state != .connected && $0.value.instance.state != .connecting })
        disconnectedPeripherals.forEach { (uuid, peripheral) in
            peripheral.instance.delegate = nil
            peripherals.removeValue(forKey: uuid)
        }
        objc_sync_exit(peripherals)
        
        var serviceUUIDs = [CBUUID]()
        if let serviceUUIDStrings = serviceUUIDStrings as? [String] {
            serviceUUIDs = serviceUUIDStrings.map { CBUUID(string: $0) }
        }
        
        var options: [String: Any]?
        if allowDuplicates {
            options = [CBCentralManagerScanOptionAllowDuplicatesKey: true]
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
    
    
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber)
    {
        NSLog("Discover peripheral: \(peripheral.name ?? "NO NAME")");
        
        var cp: Peripheral? = nil
        objc_sync_enter(peripherals)
        if let p = peripherals[peripheral.uuidAsString()] {
            cp = p
            cp?.setRSSI(RSSI)
            cp?.setAdvertisementData(advertisementData)
        } else {
            cp = Peripheral(peripheral:peripheral, rssi:RSSI, advertisementData:advertisementData)
            peripherals[peripheral.uuidAsString()] = cp
        }
        objc_sync_exit(peripherals)
        
        if (hasListeners) {
            sendEvent(withName: "BleManagerDiscoverPeripheral", body: cp?.advertisingInfo())
        }
        
    }
    
    @objc func connect(_ peripheralUUID: String, options: NSDictionary, callback: @escaping RCTResponseSenderBlock) {
        NSLog("Connect")
        
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
    
    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral)
    {
        NSLog("Peripheral Connected: \(peripheral.uuidAsString() ?? "")")
        peripheral.delegate = self
        
        /*
         The state of the peripheral isn't necessarily updated until a small
         delay after didConnectPeripheral is called and in the meantime
         didFailToConnectPeripheral may be called
         */
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.002) {
            // didFailToConnectPeripheral should have been called already if not connected by now
            
            self.invokeAndClearDictionary(&self.connectCallbacks, withKey: peripheral.uuidAsString(), usingParameters: [NSNull()])
            
            if self.hasListeners {
                self.sendEvent(withName: "BleManagerConnectPeripheral", body: ["peripheral": peripheral.uuidAsString()])
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?)
    {
        let errorStr = "Peripheral connection failure: \(peripheral.uuidAsString() ?? "") (\(error?.localizedDescription ?? "")"
        NSLog(errorStr)
        
        invokeAndClearDictionary(&connectCallbacks, withKey: peripheral.uuidAsString(), usingParameters: [errorStr])
    }
    
    
    
}
