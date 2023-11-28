import Foundation
import CoreBluetooth


@objc(BleManager)
class BleManager: NSObject, CBCentralManagerDelegate {
    
    static var shared:BleManager?
    static var sharedManager:CBCentralManager?
    
    private var manager: CBCentralManager?
    private var scanTimer: Timer?
    
    private var peripherals: NSMutableSet
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
        peripherals = NSMutableSet()
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
    
    @objc static func requiresMainQueueSetup() -> Bool { return true }
    
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
            if let peripheral = p as? CBPeripheral {
                peripheral.delegate = nil
            }
        }
        objc_sync_exit(peripherals)
        
        peripherals = NSMutableSet()
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        //
    }
}
