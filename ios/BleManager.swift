import Foundation
import CoreBluetooth


@objc(BleManager)
class BleManager: RCTEventEmitter, CBCentralManagerDelegate {
    
    static var shared:BleManager?
    static var sharedManager:CBCentralManager?
    
    private var hasListeners:Bool = false
    
    private var manager: CBCentralManager?
    private var scanTimer: Timer?
    
    private var peripherals: Set<Peripheral>
    private var connectCallbacks: NSMutableDictionary
    private var retrieveServicesLatches: NSMutableDictionary
    private var readCallbacks: NSMutableDictionary
    private var readRSSICallbacks: NSMutableDictionary
    private var readDescriptorCallbacks: NSMutableDictionary
    private var retrieveServicesCallbacks: NSMutableDictionary
    private var writeCallbacks: NSMutableDictionary
    private var writeQueue: NSMutableArray
    private var notificationCallbacks: NSMutableDictionary
    private var stopNotificationCallbacks: NSMutableDictionary
    
    private override init() {
        peripherals = []
        connectCallbacks = NSMutableDictionary()
        retrieveServicesLatches = NSMutableDictionary()
        readCallbacks = NSMutableDictionary()
        readRSSICallbacks = NSMutableDictionary()
        readDescriptorCallbacks = NSMutableDictionary()
        retrieveServicesCallbacks = NSMutableDictionary()
        writeCallbacks = NSMutableDictionary()
        writeQueue = NSMutableArray()
        notificationCallbacks = NSMutableDictionary()
        stopNotificationCallbacks = NSMutableDictionary()
        
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
        for p in peripherals {
            p.peripheral.delegate = nil
        }
        objc_sync_exit(peripherals)
        
        peripherals = []
    }
    
    @objc public func start(_ options: NSDictionary, callback: RCTResponseSenderBlock) {
        NSLog("BleManager initialized")
        var initOptions = [String: Any]()
        
        if let showAlert = options["showAlert"] as? Bool {
            initOptions[CBCentralManagerOptionShowPowerAlertKey] = showAlert
        }
        
        var queue: DispatchQueue
        if let queueIdentifierKey = options["queueIdentifierKey"] as? String {
            //let queueAttributes = DispatchQueue.Attributes.qosClass(.background)
            //queue = DispatchQueue(label: queueIdentifierKey, attributes: queueAttributes)
            queue = DispatchQueue(label: queueIdentifierKey)
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
        let connectedPeripherals = peripherals.compactMap { peripheral -> CBPeripheral? in
            guard let peripheral = peripheral.peripheral as? CBPeripheral,
                  peripheral.state != .connected && peripheral.state != .connecting else {
                return nil
            }
            return peripheral
        }
        connectedPeripherals.forEach { peripheral in
            peripherals.remove(Peripheral(peripheral:peripheral))
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
        
        NSLog("")
        if timeoutSeconds.doubleValue > 0 {
            DispatchQueue.main.async {
                self.scanTimer = Timer.scheduledTimer(withTimeInterval: timeoutSeconds.doubleValue, repeats: false) { timer in
                    NSLog("Stop scan");
                    self.scanTimer = nil;
                    self.manager?.stopScan()
                    if self.hasListeners {
                        self.sendEvent(withName: "BleManagerStopScan", body: ["status": 10])
                    }
                }
            }
        }
        
        callback([])
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
        
        let cp = Peripheral(peripheral:peripheral, rssi:RSSI, advertisementData:advertisementData)
        objc_sync_enter(peripherals)
        peripherals.insert(cp)
        objc_sync_exit(peripherals)
        
        if (hasListeners) {
            sendEvent(withName: "BleManagerDiscoverPeripheral", body: cp.advertisingInfo())
        }
        
    }
}
