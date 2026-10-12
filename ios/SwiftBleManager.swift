import CoreBluetooth
import Foundation

@objc
public class SwiftBleManager: NSObject, CBCentralManagerDelegate,
    CBPeripheralDelegate
{
    static var shared: SwiftBleManager?
    static var sharedManager: CBCentralManager?
    // The queue sharedManager delivers its delegate callbacks on, kept with
    // it because a manager reused through state restoration keeps the queue
    // it was created with.
    private static var sharedManagerQueue: DispatchQueue?

    private weak var bleManager: BleManager?
    private var manager: CBCentralManager?
    private var scanTimer: Timer?

    private var peripherals: [String: Peripheral]
    private var connectCallbacks: [String: [RCTResponseSenderBlock]]
    private var readCallbacks: [String: [RCTResponseSenderBlock]]
    private var readRSSICallbacks: [String: [RCTResponseSenderBlock]]
    private var readDescriptorCallbacks: [String: [RCTResponseSenderBlock]]
    private var writeDescriptorCallbacks: [String: [RCTResponseSenderBlock]]
    private var retrieveServicesCallbacks: [String: [RCTResponseSenderBlock]]
    private var writeCallbacks: [String: [RCTResponseSenderBlock]]
    private var writeQueues: [String: [Data]]
    private var notificationCallbacks: [String: [RCTResponseSenderBlock]]
    private var stopNotificationCallbacks: [String: [RCTResponseSenderBlock]]
    private var bufferedCharacteristics: [String: NotifyBufferContainer]

    private var connectedPeripherals: Set<String>

    private var retrieveServicesLatches: [String: Set<CBService>]
    private var characteristicsLatches: [String: Set<CBCharacteristic>]
    // Peripherals whose current discovery was abandoned, because it failed
    // as a stale GATT cache or ran out of time. Its latch is dropped when it
    // is marked, so its replies still in flight settle nothing, and the mark
    // stops them from starting further requests. Those requests would
    // interleave with a retry's discovery, and on a stale table every reply
    // is another chance for CoreBluetooth to route it to the wrong attribute
    // and abort. Cleared when a services reply arrives that a pending call is
    // waiting for. Touched only on the delegate queue, like the latches.
    private var abandonedDiscoveries = Set<String>()

    private let serialQueue = DispatchQueue(label: "BleManager.serialQueue")

    // Structured error payload so JS can detect specific failures by (domain, code).
    private static func errorPayload(_ error: Error) -> [String: Any] {
        return [
            "code": error._code,
            "domain": error._domain,
            "message": error.localizedDescription,
        ]
    }

    // The structured errors this module raises itself, rather than passes
    // on from CoreBluetooth, use the same shape in their own domain.
    static let errorDomain = "BleManagerErrorDomain"

    enum ErrorCode: Int {
        // The attribute table iOS cached for the peripheral no longer matches
        // the device (see failRetrieveServicesForStaleGattCache).
        case staleGattCache = 1
        // retrieveServices was still pending when the retrieveServicesTimeout
        // start option ran out (see armRetrieveServicesTimeout).
        case retrieveServicesTimeout = 2
    }

    private static func errorPayload(_ code: ErrorCode, message: String)
        -> [String: Any]
    {
        return [
            "code": code.rawValue,
            "domain": errorDomain,
            "message": message,
        ]
    }

    private var exactAdvertisingName: [String]

    static var verboseLogging = false

    // From the discoverIncludedServices start option. Skipping the
    // included-services request also skips the second characteristic
    // discovery didDiscoverIncludedServicesFor starts for every service.
    private var discoverIncludedServices = true

    // From the retrieveServicesTimeout start option, in seconds; nil leaves a
    // pending retrieveServices waiting on CoreBluetooth for as long as it
    // takes.
    private var retrieveServicesTimeout: TimeInterval?
    // One token per retrieveServices call, per peripheral, so a timer armed
    // for an earlier call never fails a later one. Kept under serialQueue.
    private var retrieveServicesAttempts = [String: Int]()
    // discoverServices requests sent and not yet answered, per peripheral.
    // Kept under serialQueue.
    private var unansweredServicesRequests = [String: Int]()
    // Services replies owed to calls that timed out with their requests
    // still unanswered, per peripheral. Each is dropped when it arrives,
    // error and all, so it can't settle or fail a retry in its place. Kept
    // under serialQueue.
    private var owedServicesReplies = [String: Int]()
    // The services retries asked for while replies were still owed; an
    // empty set asks for all of them. Their request is held back until the
    // owed replies have arrived, so the next replies are the owed ones. A
    // hold also ends when a held retry's own timeout passes, or on a
    // disconnect. Kept under serialQueue.
    private var heldServicesRequests = [String: Set<CBUUID>]()

    @objc public init(bleManager: BleManager) {
        peripherals = [:]
        connectCallbacks = [:]
        readCallbacks = [:]
        readRSSICallbacks = [:]
        readDescriptorCallbacks = [:]
        writeDescriptorCallbacks = [:]
        retrieveServicesCallbacks = [:]
        writeCallbacks = [:]
        writeQueues = [:]
        notificationCallbacks = [:]
        stopNotificationCallbacks = [:]
        bufferedCharacteristics = [:]
        retrieveServicesLatches = [:]
        characteristicsLatches = [:]
        exactAdvertisingName = []
        connectedPeripherals = []
        self.bleManager = bleManager

        super.init()

        NSLog("BleManager created")

        SwiftBleManager.shared = self

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(bridgeReloading),
            name: NSNotification.Name(
                rawValue: "RCTBridgeWillReloadNotification"
            ),
            object: nil
        )
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
                foundPeripheral = peripheral
            }
        }

        return foundPeripheral
    }

    // Helper method to insert callback in different queues
    func insertCallback(
        _ callback: @escaping RCTResponseSenderBlock,
        intoDictionary dictionary: inout [String: [RCTResponseSenderBlock]],
        withKey key: String
    ) {
        serialQueue.sync {
            var peripheralCallbacks =
                dictionary[key] ?? [RCTResponseSenderBlock]()
            peripheralCallbacks.append(callback)
            dictionary[key] = peripheralCallbacks
        }
    }

    // Helper method to call the callbacks for a specific peripheral and clear the queue
    func invokeAndClearDictionary(
        _ dictionary: inout [String: [RCTResponseSenderBlock]],
        withKey key: String,
        usingParameters parameters: [Any]
    ) {
        serialQueue.sync {
            invokeAndClearDictionary_THREAD_UNSAFE(
                &dictionary,
                withKey: key,
                usingParameters: parameters
            )
        }
    }

    private func enqueueSplitMessages(
        _ messages: [Data],
        forKey key: String
    ) -> (firstChunk: Data?, remainingCount: Int) {
        var chunkToSend: Data?
        var remainingCount = 0

        serialQueue.sync {
            var queue = writeQueues[key] ?? []
            queue.append(contentsOf: messages)

            if !queue.isEmpty {
                chunkToSend = queue.removeFirst()
            }

            remainingCount = queue.count
            writeQueues[key] = queue
        }

        return (chunkToSend, remainingCount)
    }

    private func dequeueNextSplitMessage(forKey key: String) -> Data? {
        var nextMessage: Data?

        serialQueue.sync {
            if var queue = writeQueues[key], !queue.isEmpty {
                nextMessage = queue.removeFirst()
                writeQueues[key] = queue
            } else {
                writeQueues.removeValue(forKey: key)
            }
        }

        return nextMessage
    }

    func invokeAndClearDictionary_THREAD_UNSAFE(
        _ dictionary: inout [String: [RCTResponseSenderBlock]],
        withKey key: String,
        usingParameters parameters: [Any]
    ) {
        if let peripheralCallbacks = dictionary[key] {
            for callback in peripheralCallbacks {
                callback(parameters)
            }

            dictionary.removeValue(forKey: key)
        }
    }

    @objc func getContext(
        _ peripheralUUIDString: String,
        serviceUUIDString: String,
        characteristicUUIDString: String,
        prop: CBCharacteristicProperties,
        callback: @escaping RCTResponseSenderBlock
    ) -> BLECommandContext? {
        // Validate UUID formats to prevent CBUUID(string:) crash
        guard Helper.isValidBLEUUID(serviceUUIDString) else {
            let error = "Invalid service UUID format: \(serviceUUIDString)"
            NSLog(error)
            callback([error])
            return nil
        }
        
        guard Helper.isValidBLEUUID(characteristicUUIDString) else {
            let error = "Invalid characteristic UUID format: \(characteristicUUIDString)"
            NSLog(error)
            callback([error])
            return nil
        }
        
        let serviceUUID = CBUUID(string: serviceUUIDString)
        let characteristicUUID = CBUUID(string: characteristicUUIDString)

        guard let peripheral = peripherals[peripheralUUIDString] else {
            let error = String(
                format: "Could not find peripheral with UUID %@",
                peripheralUUIDString
            )
            NSLog(error)
            callback([error])
            return nil
        }

        guard
            let service = Helper.findService(
                fromUUID: serviceUUID,
                peripheral: peripheral.instance
            )
        else {
            let error = String(
                format:
                    "Could not find service with UUID %@ on peripheral with UUID %@",
                serviceUUIDString,
                peripheral.instance.uuidAsString()
            )
            NSLog(error)
            callback([error])
            return nil
        }

        var characteristic = Helper.findCharacteristic(
            fromUUID: characteristicUUID,
            service: service,
            prop: prop
        )

        // Special handling for INDICATE. If characteristic with notify is not found, check for indicate.
        if prop == CBCharacteristicProperties.notify && characteristic == nil {
            characteristic = Helper.findCharacteristic(
                fromUUID: characteristicUUID,
                service: service,
                prop: CBCharacteristicProperties.indicate
            )
        }

        // As a last resort, try to find ANY characteristic with this UUID, even if it doesn't have the correct properties
        if characteristic == nil {
            characteristic = Helper.findCharacteristic(
                fromUUID: characteristicUUID,
                service: service
            )
        }

        guard let finalCharacteristic = characteristic else {
            let error = String(
                format:
                    "Could not find characteristic with UUID %@ on service with UUID %@ on peripheral with UUID %@",
                characteristicUUIDString,
                serviceUUIDString,
                peripheral.instance.uuidAsString()
            )
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

    @objc public func start(
        _ options: NSDictionary,
        callback: RCTResponseSenderBlock
    ) {
        if SwiftBleManager.verboseLogging {
            NSLog("BleManager initialized")
        }
        if let bluetoothUsageDescription = Bundle.main.object(
            forInfoDictionaryKey: "NSBluetoothAlwaysUsageDescription"
        ) as? String {
            // NSBluetoothAlwaysUsageDescription is ok
        } else {
            let error =
                "NSBluetoothAlwaysUsageDescription is not set in the infoPlist"
            NSLog(error)
            callback([error])
            return
        }
        var initOptions = [String: Any]()

        if let showAlert = options["showAlert"] as? Bool {
            initOptions[CBCentralManagerOptionShowPowerAlertKey] = showAlert
        }

        if let verboseLogging = options["verboseLogging"] as? Bool {
            SwiftBleManager.verboseLogging = verboseLogging
        }

        discoverIncludedServices =
            options["discoverIncludedServices"] as? Bool ?? true

        let timeoutMilliseconds =
            options["retrieveServicesTimeout"] as? Double ?? 0
        retrieveServicesTimeout =
            timeoutMilliseconds > 0 ? timeoutMilliseconds / 1000 : nil

        var queue: DispatchQueue
        if let queueIdentifierKey = options["queueIdentifierKey"] as? String {
            queue = DispatchQueue(
                label: queueIdentifierKey,
                qos: DispatchQoS.background
            )
        } else {
            queue = DispatchQueue.main
        }

        if let restoreIdentifierKey = options["restoreIdentifierKey"] as? String
        {
            initOptions[CBCentralManagerOptionRestoreIdentifierKey] =
                restoreIdentifierKey

            if let sharedManager = SwiftBleManager.sharedManager {
                manager = sharedManager
                manager?.delegate = self
            } else {
                manager = CBCentralManager(
                    delegate: self,
                    queue: queue,
                    options: initOptions
                )
                SwiftBleManager.sharedManager = manager
                SwiftBleManager.sharedManagerQueue = queue
            }
        } else {
            manager = CBCentralManager(
                delegate: self,
                queue: queue,
                options: initOptions
            )
            SwiftBleManager.sharedManager = manager
            SwiftBleManager.sharedManagerQueue = queue
        }

        callback([])
    }

    @objc public func isStarted(_ callback: RCTResponseSenderBlock) {
        let started = manager != nil
        callback([NSNull(), started])
    }

    @objc public func scan(
        _ scanningOptions: NSDictionary,
        callback: RCTResponseSenderBlock
    ) {
        if Int(truncating: scanningOptions["seconds"] as? NSNumber ?? 0) > 0 {
            NSLog("scan with timeout \(scanningOptions["seconds"] ?? 0)")
        } else {
            NSLog("scan")
        }

        // Clear the peripherals before scanning again, otherwise cannot connect again after disconnection
        // Only clear peripherals that are not connected - otherwise connections fail silently (without any
        // onDisconnect* callback).
        serialQueue.sync {
            let disconnectedPeripherals = peripherals.filter({
                $0.value.instance.state != .connected
                    && $0.value.instance.state != .connecting
            })
            disconnectedPeripherals.forEach { (uuid, peripheral) in
                peripheral.instance.delegate = nil
                peripherals.removeValue(forKey: uuid)
            }
        }

        var serviceUUIDs = [CBUUID]()
        if let serviceUUIDStrings = scanningOptions["serviceUUIDs"]
            as? [String]
        {
            // Validate UUID formats to prevent CBUUID(string:) crash
            for uuidString in serviceUUIDStrings {
                if Helper.isValidBLEUUID(uuidString) {
                    serviceUUIDs.append(CBUUID(string: uuidString))
                } else {
                    NSLog("Warning: Invalid UUID format in scan options: \(uuidString), skipping")
                }
            }
            // If serviceUUIDs were provided but none were valid, return error
            if !serviceUUIDStrings.isEmpty && serviceUUIDs.isEmpty {
                let error = "Invalid UUID format in serviceUUIDs: all UUIDs are invalid"
                NSLog(error)
                callback([error])
                return
            }
        }

        var options: [String: Any]?
        let allowDuplicates =
            scanningOptions["allowDuplicates"] as? Bool ?? false
        if allowDuplicates {
            options = [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        }

        exactAdvertisingName.removeAll()
        if let names = scanningOptions["exactAdvertisingName"] as? [String] {
            exactAdvertisingName.append(contentsOf: names)
        }

        manager?.scanForPeripherals(
            withServices: serviceUUIDs,
            options: options
        )

        let timeoutSeconds = scanningOptions["seconds"] as? Double ?? 0
        if timeoutSeconds > 0 {
            if let scanTimer = scanTimer {
                scanTimer.invalidate()
                self.scanTimer = nil
            }
            DispatchQueue.main.async {
                self.scanTimer = Timer.scheduledTimer(
                    timeInterval: timeoutSeconds,
                    target: self,
                    selector: #selector(self.stopTimer),
                    userInfo: nil,
                    repeats: false
                )
            }
        }

        callback([])
    }

    @objc func stopTimer() {
        NSLog("Stop scan")
        scanTimer = nil
        manager?.stopScan()
        bleManager?.emit(onStopScan: ["status": 10])
    }

    @objc public func stopScan(_ callback: @escaping RCTResponseSenderBlock) {
        if let scanTimer = self.scanTimer {
            scanTimer.invalidate()
            self.scanTimer = nil
        }

        manager?.stopScan()

        bleManager?.emit(onStopScan: ["status": 0])

        callback([])
    }

    @objc public func connect(
        _ peripheralUUID: String,
        options: NSDictionary,
        callback: @escaping RCTResponseSenderBlock
    ) {

        if let peripheral = peripherals[peripheralUUID] {
            // Found the peripheral, connect to it
            NSLog("Connecting to peripheral with UUID: \(peripheralUUID)")

            insertCallback(
                callback,
                intoDictionary: &connectCallbacks,
                withKey: peripheral.instance.uuidAsString()
            )
            manager?.connect(peripheral.instance)
        } else {
            // Try to retrieve the peripheral
            NSLog("Retrieving peripheral with UUID: \(peripheralUUID)")

            if let uuid = UUID(uuidString: peripheralUUID) {
                let peripheralArray = manager?.retrievePeripherals(
                    withIdentifiers: [uuid])
                if let retrievedPeripheral = peripheralArray?.first {
                    serialQueue.sync {
                        peripherals[retrievedPeripheral.uuidAsString()] =
                            Peripheral(peripheral: retrievedPeripheral)
                    }
                    NSLog(
                        "Successfully retrieved and connecting to peripheral with UUID: \(peripheralUUID)"
                    )

                    // Connect to the retrieved peripheral
                    insertCallback(
                        callback,
                        intoDictionary: &connectCallbacks,
                        withKey: retrievedPeripheral.uuidAsString()
                    )
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

    @objc public func disconnect(
        _ peripheralUUID: String,
        force: Bool,
        callback: @escaping RCTResponseSenderBlock
    ) {
        if let peripheral = peripherals[peripheralUUID] {
            NSLog("Disconnecting from peripheral with UUID: \(peripheralUUID)")

            for service in peripheral.instance.safeServices.attributes {
                for characteristic in service.safeCharacteristics.attributes
                where characteristic.isNotifying {
                    NSLog(
                        "Remove notification from: \(characteristic.uuid)"
                    )
                    peripheral.instance.setNotifyValue(
                        false,
                        for: characteristic
                    )
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

    @objc public func retrieveServices(
        _ peripheralUUID: String,
        services: [String],
        callback: @escaping RCTResponseSenderBlock
    ) {
        NSLog("retrieveServices \(services)")

        if let peripheral = peripherals[peripheralUUID],
            peripheral.instance.state == .connected
        {
            // Validated before the callback is queued: a call rejected here
            // but left queued would be called again when the next discovery
            // on this peripheral settles, and React Native's TurboModule
            // bridge treats a second call as fatal.
            var uuids: [CBUUID] = []
            for string in services {
                // Validate UUID format to prevent CBUUID(string:) crash
                guard Helper.isValidBLEUUID(string) else {
                    let error = "Invalid service UUID format: \(string)"
                    NSLog(error)
                    callback([error])
                    return
                }
                uuids.append(CBUUID(string: string))
            }

            let key = peripheral.instance.uuidAsString()
            // Queued and numbered in one step, so a timeout armed for an
            // earlier call can tell that this one has started. While a
            // timed-out call's services reply is still owed, the request is
            // held back (see heldServicesRequests).
            let (attempt, sendNow): (Int, Bool) = serialQueue.sync {
                retrieveServicesCallbacks[key, default: []].append(callback)
                let next = (retrieveServicesAttempts[key] ?? 0) + 1
                retrieveServicesAttempts[key] = next
                guard (owedServicesReplies[key] ?? 0) == 0 else {
                    heldServicesRequests[key] = SwiftBleManager.mergedServices(
                        heldServicesRequests[key], uuids
                    )
                    return (next, false)
                }
                unansweredServicesRequests[key, default: 0] += 1
                return (next, true)
            }

            if sendNow {
                if !uuids.isEmpty {
                    peripheral.instance.discoverServices(uuids)
                } else {
                    peripheral.instance.discoverServices(nil)
                }
            }

            if let timeout = retrieveServicesTimeout {
                armRetrieveServicesTimeout(
                    forKey: key,
                    attempt: attempt,
                    after: timeout
                )
            }

        } else {
            callback(["Peripheral not found or not connected"])
        }
    }

    // One held request covering every retry that asked while a reply was
    // owed: all services if any of them asked for all.
    private static func mergedServices(
        _ held: Set<CBUUID>?, _ uuids: [CBUUID]
    ) -> Set<CBUUID> {
        guard let held = held else { return Set(uuids) }
        return held.isEmpty || uuids.isEmpty ? [] : held.union(uuids)
    }

    // Rejects the retrieveServices calls still pending on a peripheral when
    // the timeout armed by the latest of them runs out, so the JS promise
    // settles instead of waiting on a discovery CoreBluetooth never
    // completes. Each call restarts the timeout, and the calls pending on a
    // peripheral settle together, as they do when discovery completes. The
    // timer runs on the delegate queue, ordered with the discovery replies,
    // and retires the timed-out discovery the way a stale failure does: its
    // latch is dropped and it is marked abandoned, so it sends no further
    // requests and is not finished in the background. Services replies it
    // was still waiting for are dropped when they arrive, with a retry's
    // request held back until then, or until the retry's own timeout passes.
    // This relies on CoreBluetooth answering a peripheral's discovery
    // requests in the order they were sent: then all of its late replies
    // arrive before a retry's services reply and find no latch to settle. If
    // a retry were answered ahead of them, they could still settle it, as
    // with overlapping calls.
    private func armRetrieveServicesTimeout(
        forKey key: String,
        attempt: Int,
        after timeout: TimeInterval
    ) {
        let delegateQueue =
            SwiftBleManager.sharedManagerQueue ?? DispatchQueue.main
        delegateQueue.asyncAfter(deadline: .now() + timeout) {
            [weak self] in
            guard let self = self else { return }
            let message =
                "retrieveServices timed out after \(Int(timeout * 1000)) ms for peripheral \(key)"
            // Checked, retired and answered in one step, so a call queued in
            // between is never failed by this older timer.
            self.serialQueue.sync {
                guard self.retrieveServicesAttempts[key] == attempt,
                    self.retrieveServicesCallbacks[key] != nil
                else { return }
                self.retrieveServicesLatches.removeValue(forKey: key)
                self.abandonedDiscoveries.insert(key)
                if self.heldServicesRequests.removeValue(forKey: key) != nil {
                    // These calls never sent their request: a whole timeout
                    // passed with earlier replies still owed, so they are
                    // taken to be lost and nothing is owed any more.
                    self.owedServicesReplies.removeValue(forKey: key)
                    self.unansweredServicesRequests.removeValue(forKey: key)
                } else if let unanswered = self.unansweredServicesRequests[key],
                    unanswered > 0
                {
                    self.owedServicesReplies[key] = unanswered
                }
                NSLog("%@", message)
                self.invokeAndClearDictionary_THREAD_UNSAFE(
                    &self.retrieveServicesCallbacks,
                    withKey: key,
                    usingParameters: [
                        SwiftBleManager.errorPayload(
                            .retrieveServicesTimeout,
                            message: message
                        )
                    ]
                )
            }
        }
    }

    @objc public func readRSSI(
        _ peripheralUUID: String,
        callback: @escaping RCTResponseSenderBlock
    ) {
        NSLog("readRSSI")

        if let peripheral = peripherals[peripheralUUID],
            peripheral.instance.state == .connected
        {
            insertCallback(
                callback,
                intoDictionary: &readRSSICallbacks,
                withKey: peripheral.instance.uuidAsString()
            )
            peripheral.instance.readRSSI()
        } else {
            callback(["Peripheral not found or not connected"])
        }
    }

    @objc public func readDescriptor(
        _ peripheralUUID: String,
        serviceUUID: String,
        characteristicUUID: String,
        descriptorUUID: String,
        callback: @escaping RCTResponseSenderBlock
    ) {
        NSLog("readDescriptor")

        guard
            let context = getContext(
                peripheralUUID,
                serviceUUIDString: serviceUUID,
                characteristicUUIDString: characteristicUUID,
                prop: CBCharacteristicProperties.read,
                callback: callback
            )
        else {
            return
        }

        let peripheral = context.peripheral
        let characteristic = context.characteristic

        // Validate UUID format to prevent CBUUID(string:) crash
        guard Helper.isValidBLEUUID(descriptorUUID) else {
            let error = "Invalid descriptor UUID format: \(descriptorUUID)"
            NSLog(error)
            callback([error])
            return
        }

        guard
            let descriptor = Helper.findDescriptor(
                fromUUID: CBUUID(string: descriptorUUID),
                characteristic: characteristic!
            )
        else {
            let error =
                "Could not find descriptor with UUID \(descriptorUUID) on characteristic with UUID \(String(describing: characteristic?.uuid.uuidString)) on peripheral with UUID \(peripheralUUID)"
            NSLog(error)
            callback([error])
            return
        }

        if let peripheral = peripheral?.instance {
            let key = Helper.key(
                forPeripheral: peripheral,
                andCharacteristic: characteristic!,
                andDescriptor: descriptor
            )
            insertCallback(
                callback,
                intoDictionary: &readDescriptorCallbacks,
                withKey: key
            )

        }

        peripheral?.instance.readValue(for: descriptor)
    }

    @objc public func writeDescriptor(
        _ peripheralUUID: String,
        serviceUUID: String,
        characteristicUUID: String,
        descriptorUUID: String,
        message: [UInt8],
        callback: @escaping RCTResponseSenderBlock
    ) {
        NSLog("writeDescriptor")

        guard
            let context = getContext(
                peripheralUUID,
                serviceUUIDString: serviceUUID,
                characteristicUUIDString: characteristicUUID,
                prop: CBCharacteristicProperties.read,
                callback: callback
            )
        else {
            return
        }

        let peripheral = context.peripheral
        let characteristic = context.characteristic

        // Validate UUID format to prevent CBUUID(string:) crash
        guard Helper.isValidBLEUUID(descriptorUUID) else {
            let error = "Invalid descriptor UUID format: \(descriptorUUID)"
            NSLog(error)
            callback([error])
            return
        }

        guard
            let descriptor = Helper.findDescriptor(
                fromUUID: CBUUID(string: descriptorUUID),
                characteristic: characteristic!
            )
        else {
            let error =
                "Could not find descriptor with UUID \(descriptorUUID) on characteristic with UUID \(String(describing: characteristic?.uuid.uuidString)) on peripheral with UUID \(peripheralUUID)"
            NSLog(error)
            callback([error])
            return
        }

        if let peripheral = peripheral?.instance {
            let key = Helper.key(
                forPeripheral: peripheral,
                andCharacteristic: characteristic!,
                andDescriptor: descriptor
            )
            insertCallback(
                callback,
                intoDictionary: &writeDescriptorCallbacks,
                withKey: key
            )

        }

        let dataMessage = Data(message)
        peripheral?.instance.writeValue(dataMessage, for: descriptor)
    }

    @objc public func getDiscoveredPeripherals(
        _ callback: @escaping RCTResponseSenderBlock
    ) {
        NSLog("Get discovered peripherals")
        var discoveredPeripherals: [[String: Any]] = []

        serialQueue.sync {
            for (_, peripheral) in peripherals {
                discoveredPeripherals.append(peripheral.advertisingInfo())
            }
        }

        callback([NSNull(), discoveredPeripherals])
    }

    @objc public func getConnectedPeripherals(
        _ serviceUUIDStrings: [String],
        callback: @escaping RCTResponseSenderBlock
    ) {
        NSLog("Get connected peripherals")
        var serviceUUIDs: [CBUUID] = []

        for uuidString in serviceUUIDStrings {
            // Validate BLE UUID format to prevent CBUUID(string:) crash
            guard Helper.isValidBLEUUID(uuidString) else {
                let error = uuidString.isEmpty ? "Invalid UUID: empty string" : "Invalid UUID format: \(uuidString)"
                NSLog(error)
                callback([error])
                return
            }
            
            // Create CBUUID only with validated UUID string (prevents crash)
            serviceUUIDs.append(CBUUID(string: uuidString))
        }

        var connectedPeripherals: [Peripheral] = []

        if serviceUUIDs.isEmpty {
            serialQueue.sync {
                connectedPeripherals = peripherals.filter({
                    $0.value.instance.state == .connected
                }).map({ p in
                    p.value
                })
            }
        } else {
            let connectedCBPeripherals: [CBPeripheral] =
                manager?.retrieveConnectedPeripherals(
                    withServices: serviceUUIDs
                ) ?? []

            serialQueue.sync {
                for ph in connectedCBPeripherals {
                    if let peripheral = peripherals[ph.uuidAsString()] {
                        connectedPeripherals.append(peripheral)
                    } else {
                        peripherals[ph.uuidAsString()] = Peripheral(
                            peripheral: ph
                        )
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

    @objc public func isPeripheralConnected(
        _ peripheralUUID: String,
        callback: @escaping RCTResponseSenderBlock
    ) {

        if let peripheral = peripherals[peripheralUUID] {
            callback([NSNull(), peripheral.instance.state == .connected])
        } else {
            callback(["Peripheral not found"])
        }
    }

    @objc public func isScanning(_ callback: @escaping RCTResponseSenderBlock) {
        if let manager = manager {
            callback([NSNull(), manager.isScanning])
        } else {
            callback(["CBCentralManager not found"])
        }
    }

    @objc public func checkState(_ callback: @escaping RCTResponseSenderBlock) {
        if let manager = manager {
            centralManagerDidUpdateState(manager)

            let stateName = Helper.centralManagerStateToString(manager.state)
            callback([stateName])
        }
    }

    @objc public func write(
        _ peripheralUUID: String,
        serviceUUID: String,
        characteristicUUID: String,
        message: [UInt8],
        maxByteSize: Int,
        callback: @escaping RCTResponseSenderBlock
    ) {
        NSLog("write")

        guard
            let context = getContext(
                peripheralUUID,
                serviceUUIDString: serviceUUID,
                characteristicUUIDString: characteristicUUID,
                prop: CBCharacteristicProperties.write,
                callback: callback
            )
        else {
            return
        }

        let dataMessage = Data(message)

        if let peripheral = context.peripheral,
            let characteristic = context.characteristic
        {
            let key = Helper.key(
                forPeripheral: peripheral.instance,
                andCharacteristic: characteristic
            )
            insertCallback(
                callback,
                intoDictionary: &writeCallbacks,
                withKey: key
            )

            if SwiftBleManager.verboseLogging {
                NSLog(
                    "Message to write(\(dataMessage.count)): \(dataMessage.hexadecimalString())"
                )
            }

            if dataMessage.count > maxByteSize {
                var count = 0
                var offset = 0
                var splitMessages = [Data]()

                while count < dataMessage.count,
                    (dataMessage.count - count) > maxByteSize
                {
                    let splitMessage = dataMessage.subdata(
                        in: offset..<offset + maxByteSize
                    )
                    splitMessages.append(splitMessage)
                    count += maxByteSize
                    offset += maxByteSize
                }

                if count < dataMessage.count {
                    let splitMessage = dataMessage.subdata(
                        in: offset..<dataMessage.count
                    )
                    splitMessages.append(splitMessage)
                }

                let enqueueResult = enqueueSplitMessages(
                    splitMessages,
                    forKey: key
                )

                if SwiftBleManager.verboseLogging {
                    NSLog(
                        "Queued splitted message for \(key): \(enqueueResult.remainingCount) chunk(s) pending"
                    )
                }

                if let firstMessage = enqueueResult.firstChunk {
                    peripheral.instance.writeValue(
                        firstMessage,
                        for: characteristic,
                        type: .withResponse
                    )
                }
            } else {
                peripheral.instance.writeValue(
                    dataMessage,
                    for: characteristic,
                    type: .withResponse
                )
            }
        }
    }

    @objc public func writeWithoutResponse(
        _ peripheralUUID: String,
        serviceUUID: String,
        characteristicUUID: String,
        message: [UInt8],
        maxByteSize: Int,
        queueSleepTime: Int,
        callback: @escaping RCTResponseSenderBlock
    ) {
        NSLog("writeWithoutResponse")

        guard
            let context = getContext(
                peripheralUUID,
                serviceUUIDString: serviceUUID,
                characteristicUUIDString: characteristicUUID,
                prop: CBCharacteristicProperties.writeWithoutResponse,
                callback: callback
            )
        else {
            return
        }

        let dataMessage = Data(message)

        if SwiftBleManager.verboseLogging {
            NSLog(
                "Message to write(\(dataMessage.count)): \(dataMessage.hexadecimalString())"
            )
        }

        if dataMessage.count > maxByteSize {
            var offset = 0
            let peripheral = context.peripheral
            guard let characteristic = context.characteristic else { return }

            repeat {
                let thisChunkSize = min(maxByteSize, dataMessage.count - offset)
                let chunk = dataMessage.subdata(
                    in: offset..<offset + thisChunkSize
                )

                offset += thisChunkSize
                peripheral?.instance.writeValue(
                    chunk,
                    for: characteristic,
                    type: .withoutResponse
                )

                let sleepTimeSeconds = TimeInterval(queueSleepTime) / 1000
                Thread.sleep(forTimeInterval: sleepTimeSeconds)
            } while offset < dataMessage.count

            callback([])
        } else {
            let peripheral = context.peripheral
            guard let characteristic = context.characteristic else { return }

            peripheral?.instance.writeValue(
                dataMessage,
                for: characteristic,
                type: .withoutResponse
            )
            callback([])
        }
    }

    @objc public func read(
        _ peripheralUUID: String,
        serviceUUID: String,
        characteristicUUID: String,
        callback: @escaping RCTResponseSenderBlock
    ) {
        NSLog("read")

        guard
            let context = getContext(
                peripheralUUID,
                serviceUUIDString: serviceUUID,
                characteristicUUIDString: characteristicUUID,
                prop: CBCharacteristicProperties.read,
                callback: callback
            )
        else {
            return
        }

        let peripheral = context.peripheral
        let characteristic = context.characteristic

        let key = Helper.key(
            forPeripheral: peripheral!.instance as CBPeripheral,
            andCharacteristic: characteristic!
        )
        insertCallback(callback, intoDictionary: &readCallbacks, withKey: key)

        peripheral?.instance.readValue(for: characteristic!)  // callback sends value
    }

    @objc public func startNotificationWithBuffer(
        _ peripheralUUID: String,
        serviceUUID: String,
        characteristicUUID: String,
        bufferLength: NSNumber,
        callback: @escaping RCTResponseSenderBlock
    ) {
        NSLog("startNotificationWithBuffer")

        guard
            let context = getContext(
                peripheralUUID,
                serviceUUIDString: serviceUUID,
                characteristicUUIDString: characteristicUUID,
                prop: CBCharacteristicProperties.notify,
                callback: callback
            )
        else { return }
        guard let peripheral = context.peripheral else { return }
        guard let characteristic = context.characteristic else { return }

        let key = Helper.key(
            forPeripheral: (peripheral.instance as CBPeripheral?)!,
            andCharacteristic: characteristic
        )
        insertCallback(
            callback,
            intoDictionary: &notificationCallbacks,
            withKey: key
        )

        self.bufferedCharacteristics[key] = NotifyBufferContainer(
            size: bufferLength.intValue
        )

        peripheral.instance.setNotifyValue(true, for: characteristic)
    }

    @objc public func startNotification(
        _ peripheralUUID: String,
        serviceUUID: String,
        characteristicUUID: String,
        callback: @escaping RCTResponseSenderBlock
    ) {
        NSLog("startNotification")

        guard
            let context = getContext(
                peripheralUUID,
                serviceUUIDString: serviceUUID,
                characteristicUUIDString: characteristicUUID,
                prop: CBCharacteristicProperties.notify,
                callback: callback
            )
        else {
            return
        }

        guard let peripheral = context.peripheral else { return }
        guard let characteristic = context.characteristic else { return }

        let key = Helper.key(
            forPeripheral: (peripheral.instance as CBPeripheral?)!,
            andCharacteristic: characteristic
        )
        insertCallback(
            callback,
            intoDictionary: &notificationCallbacks,
            withKey: key
        )

        peripheral.instance.setNotifyValue(true, for: characteristic)
    }

    @objc public func stopNotification(
        _ peripheralUUID: String,
        serviceUUID: String,
        characteristicUUID: String,
        callback: @escaping RCTResponseSenderBlock
    ) {
        NSLog("stopNotification")

        guard
            let context = getContext(
                peripheralUUID,
                serviceUUIDString: serviceUUID,
                characteristicUUIDString: characteristicUUID,
                prop: CBCharacteristicProperties.notify,
                callback: callback
            )
        else {
            return
        }

        let peripheral = context.peripheral
        guard let characteristic = context.characteristic else { return }

        if characteristic.isNotifying {
            let key = Helper.key(
                forPeripheral: (peripheral?.instance as CBPeripheral?)!,
                andCharacteristic: characteristic
            )
            insertCallback(
                callback,
                intoDictionary: &stopNotificationCallbacks,
                withKey: key
            )

            // Remove any buffered data if notification was started with buffer
            self.bufferedCharacteristics.removeValue(forKey: key)

            peripheral?.instance.setNotifyValue(false, for: characteristic)
            NSLog("Characteristic stopped notifying")
        } else {
            NSLog("Characteristic is not notifying")
            callback([])
        }
    }

    @objc public func getMaximumWriteValueLengthForWithoutResponse(
        _ peripheralUUID: String,
        callback: @escaping RCTResponseSenderBlock
    ) {
        NSLog("getMaximumWriteValueLengthForWithoutResponse")

        guard let peripheral = peripherals[peripheralUUID] else {
            callback(["Peripheral not found or not connected"])
            return
        }

        if peripheral.instance.state == .connected {
            let max = NSNumber(
                value: peripheral.instance.maximumWriteValueLength(
                    for: .withoutResponse
                )
            )
            callback([NSNull(), max])
        } else {
            callback(["Peripheral not found or not connected"])
        }
    }

    @objc public func getMaximumWriteValueLengthForWithResponse(
        _ peripheralUUID: String,
        callback: @escaping RCTResponseSenderBlock
    ) {
        NSLog("getMaximumWriteValueLengthForWithResponse")

        guard let peripheral = peripherals[peripheralUUID] else {
            callback(["Peripheral not found or not connected"])
            return
        }

        if peripheral.instance.state == .connected {
            let max = NSNumber(
                value: peripheral.instance.maximumWriteValueLength(
                    for: .withResponse
                )
            )
            callback([NSNull(), max])
        } else {
            callback(["Peripheral not found or not connected"])
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        willRestoreState dict: [String: Any]
    ) {
        if let restoredPeripherals = dict[
            CBCentralManagerRestoredStatePeripheralsKey
        ] as? [CBPeripheral], restoredPeripherals.count > 0 {
            serialQueue.sync {
                var data = [[String: Any]]()
                for peripheral in restoredPeripherals {
                    let p = Peripheral(peripheral: peripheral)
                    peripherals[peripheral.uuidAsString()] = p
                    data.append(p.advertisingInfo())
                    peripheral.delegate = self
                }
                self.bleManager?.emit(onCentralManagerWillRestoreState: [
                    "peripherals": data
                ])
            }
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        NSLog("Peripheral Connected: \(peripheral.uuidAsString() )")
        peripheral.delegate = self

        /*
         The state of the peripheral isn't necessarily updated until a small
         delay after didConnectPeripheral is called and in the meantime
         didFailToConnectPeripheral may be called
         */
        DispatchQueue.main.async {
            Timer.scheduledTimer(withTimeInterval: 0.002, repeats: false) {
                timer in
                // didFailToConnectPeripheral should have been called already if not connected by now
                self.invokeAndClearDictionary(
                    &self.connectCallbacks,
                    withKey: peripheral.uuidAsString(),
                    usingParameters: [NSNull()]
                )

                self.connectedPeripherals.insert(peripheral.uuidAsString())
                self.bleManager?.emit(onConnectPeripheral: [
                    "peripheral": peripheral.uuidAsString()
                ])
            }
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        NSLog(
            "Peripheral connection failure: \(peripheral.uuidAsString() ) (\(error?.localizedDescription ?? "")"
        )

        let errorParam: Any =
            error.map(SwiftBleManager.errorPayload)
            ?? "Peripheral connection failure: \(peripheral.uuidAsString())"
        invokeAndClearDictionary(
            &connectCallbacks,
            withKey: peripheral.uuidAsString(),
            usingParameters: [errorParam]
        )
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral:
            CBPeripheral,
        error: Error?
    ) {
        let peripheralUUIDString: String = peripheral.uuidAsString()
        NSLog("Peripheral Disconnected: \(peripheralUUIDString)")

        if let error = error {
            NSLog("Error: \(error)")
        }

        let errorStr = "Peripheral did disconnect: \(peripheralUUIDString)"

        // A disconnect ends the outstanding requests, so nothing is owed on
        // the next connection.
        serialQueue.sync {
            _ = unansweredServicesRequests.removeValue(forKey: peripheralUUIDString)
            _ = owedServicesReplies.removeValue(forKey: peripheralUUIDString)
            _ = heldServicesRequests.removeValue(forKey: peripheralUUIDString)
        }

        invokeAndClearDictionary(
            &connectCallbacks,
            withKey: peripheralUUIDString,
            usingParameters: [errorStr]
        )
        invokeAndClearDictionary(
            &readRSSICallbacks,
            withKey: peripheralUUIDString,
            usingParameters: [errorStr]
        )
        invokeAndClearDictionary(
            &retrieveServicesCallbacks,
            withKey: peripheralUUIDString,
            usingParameters: [errorStr]
        )

        for key in readCallbacks.keys {
            if let keyString = key as String?,
                keyString.hasPrefix(peripheralUUIDString)
            {
                invokeAndClearDictionary(
                    &readCallbacks,
                    withKey: key,
                    usingParameters: [errorStr]
                )
            }
        }

        for key in writeCallbacks.keys {
            if let keyString = key as String?,
                keyString.hasPrefix(peripheralUUIDString)
            {
                invokeAndClearDictionary(
                    &writeCallbacks,
                    withKey: key,
                    usingParameters: [errorStr]
                )
            }
        }

        for key in notificationCallbacks.keys {
            if let keyString = key as String?,
                keyString.hasPrefix(peripheralUUIDString)
            {
                invokeAndClearDictionary(
                    &notificationCallbacks,
                    withKey: key,
                    usingParameters: [errorStr]
                )
            }
        }

        for key in readDescriptorCallbacks.keys {
            if let keyString = key as String?,
                keyString.hasPrefix(peripheralUUIDString)
            {
                invokeAndClearDictionary(
                    &readDescriptorCallbacks,
                    withKey: key,
                    usingParameters: [errorStr]
                )
            }
        }

        for key in stopNotificationCallbacks.keys {
            if let keyString = key as String?,
                keyString.hasPrefix(peripheralUUIDString)
            {
                invokeAndClearDictionary(
                    &stopNotificationCallbacks,
                    withKey: key,
                    usingParameters: [errorStr]
                )
            }
        }

        let bufferedCharacteristicsKeysToRemove = bufferedCharacteristics.keys
            .filter { key in
                if let keyString = key as String? {
                    return keyString.hasPrefix(peripheralUUIDString)
                }
                return false
            }
        for key in bufferedCharacteristicsKeysToRemove {
            bufferedCharacteristics.removeValue(forKey: key)
        }

        connectedPeripherals.remove(peripheralUUIDString)
        if let e: Error = error {
            self.bleManager?.emit(onDisconnectPeripheral: [
                "peripheral": peripheralUUIDString, "domain": e._domain,
                "code": e._code, "description": e.localizedDescription,
            ])
        } else {
            self.bleManager?.emit(onDisconnectPeripheral: [
                "peripheral": peripheralUUIDString
            ])
        }
    }

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let stateName = Helper.centralManagerStateToString(central.state)
        self.bleManager?.emit(onDidUpdateState: ["state": stateName])
        if stateName == "off" {
            for peripheralUUID in connectedPeripherals {
                if let peripheral = peripherals[peripheralUUID] {
                    if peripheral.instance.state == .disconnected {
                        self.centralManager(
                            manager!,
                            didDisconnectPeripheral: peripheral.instance,
                            error: nil
                        )
                    }
                }
            }
        }
    }

    func handleDiscoveredPeripheral(
        _ peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi: NSNumber
    ) {
        if SwiftBleManager.verboseLogging {
            NSLog("Discover peripheral: \(peripheral.name ?? "NO NAME")")
        }

        var cp: Peripheral? = nil
        serialQueue.sync {
            if let p = peripherals[peripheral.uuidAsString()] {
                cp = p
                cp?.setRSSI(rssi)
                cp?.setAdvertisementData(advertisementData)
            } else {
                cp = Peripheral(
                    peripheral: peripheral,
                    rssi: rssi,
                    advertisementData: advertisementData
                )
                peripherals[peripheral.uuidAsString()] = cp
            }
        }

        self.bleManager?.emit(onDiscoverPeripheral: cp?.advertisingInfo())
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        if exactAdvertisingName.count > 0 {
            if let peripheralName = peripheral.name {
                if exactAdvertisingName.contains(peripheralName) {
                    handleDiscoveredPeripheral(
                        peripheral,
                        advertisementData: advertisementData,
                        rssi: RSSI
                    )
                } else {
                    if let localName = advertisementData[
                        CBAdvertisementDataLocalNameKey
                    ] as? String {
                        if exactAdvertisingName.contains(localName) {
                            handleDiscoveredPeripheral(
                                peripheral,
                                advertisementData: advertisementData,
                                rssi: RSSI
                            )
                        }
                    }
                }
            }
        } else {
            handleDiscoveredPeripheral(
                peripheral,
                advertisementData: advertisementData,
                rssi: RSSI
            )
        }

    }

    // The first array in the peripheral's attribute tree that holds an
    // attribute of the wrong class, read through the KVC accessors.
    private func firstForeignArray(
        in peripheral: CBPeripheral
    ) -> (location: String, foreignClassNames: [String])? {
        let services = peripheral.safeServices
        if services.hasForeign {
            return ("services", services.foreignClassNames)
        }
        for service in services.attributes {
            let characteristics = service.safeCharacteristics
            if characteristics.hasForeign {
                return (
                    "characteristics of service \(service.uuid.uuidString)",
                    characteristics.foreignClassNames
                )
            }
            for characteristic in characteristics.attributes {
                let descriptors = characteristic.safeDescriptors
                if descriptors.hasForeign {
                    return (
                        "descriptors of characteristic \(characteristic.uuid.uuidString)",
                        descriptors.foreignClassNames
                    )
                }
            }
        }
        return nil
    }

    // The last check before a discovery reports success. Some arrays, such
    // as a characteristic's descriptors, are never iterated on the way here,
    // so the whole tree is read once more and any foreign entry fails the
    // discovery as stale.
    private func failIfTreeHoldsForeignAttributes(
        _ peripheral: CBPeripheral
    ) -> Bool {
        guard let foreign = firstForeignArray(in: peripheral) else {
            return false
        }
        failRetrieveServicesForStaleGattCache(
            peripheral,
            location: foreign.location,
            foreignClassNames: foreign.foreignClassNames
        )
        return true
    }

    // The attribute table iOS cached for this peripheral's bond no longer
    // matches the device, so CoreBluetooth built the attribute tree from the
    // wrong table and an array holds an attribute of the wrong class. Reads
    // and writes against that tree would land on the wrong handles, so the
    // pending retrieveServices fails instead. Discovering again on the same
    // connection returns the same tree; iOS reads the table again after
    // Bluetooth is turned off and on.
    private func failRetrieveServicesForStaleGattCache(
        _ peripheral: CBPeripheral,
        location: String,
        foreignClassNames: [String]
    ) {
        let key = peripheral.uuidAsString()
        // Called from the discovery delegates, so this runs on the queue that
        // owns the latches. Dropping this peripheral's latch keeps the rest of
        // the failed discovery from settling a later retrieveServices with a
        // tree read from the stale table, and marking it abandoned stops it
        // from sending further requests. characteristicsLatches is keyed by
        // service UUID alone and may belong to another peripheral's
        // discovery, so it is left for the next discovery to overwrite.
        retrieveServicesLatches.removeValue(forKey: key)
        abandonedDiscoveries.insert(key)
        let message =
            "Stale GATT cache: \(foreignClassNames.count) attribute(s) of unexpected type [\(foreignClassNames.joined(separator: ", "))] in \(location) of peripheral \(key); iOS reads the device's attribute table again after Bluetooth is turned off and on"
        NSLog("%@", message)
        invokeAndClearDictionary(
            &retrieveServicesCallbacks,
            withKey: key,
            usingParameters: [
                SwiftBleManager.errorPayload(.staleGattCache, message: message)
            ]
        )
    }

    // CoreBluetooth passes each discovery delegate the attribute it resolved
    // from the reply's handle, and Swift does not check that object's class
    // at this boundary. With a stale attribute cache it can be an attribute
    // of the wrong class. A reply without an error goes to that attribute's
    // own handler first, and CoreBluetooth aborts there before any delegate
    // runs; a reply that carries an error skips the handler and reaches the
    // delegate with the object as it is. Reading a property only the expected
    // class has, such as a characteristic's service on a CBService, then
    // raises an unrecognized selector. So the class is checked through the
    // runtime before anything else touches it, and discovery fails as stale.
    private func failIfForeignAttribute(
        _ attribute: NSObject,
        expected: AnyClass,
        peripheral: CBPeripheral,
        location: String
    ) -> Bool {
        guard !attribute.isKind(of: expected) else { return false }
        let actual = NSStringFromClass(type(of: attribute))
        failRetrieveServicesForStaleGattCache(
            peripheral,
            location: "\(location) (delegate received \(actual))",
            foreignClassNames: [actual]
        )
        return true
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {
        let key = peripheral.uuidAsString()
        // A reply owed to a timed-out call is dropped, error and all. Once the
        // last owed reply is in, a retry held back meanwhile sends its request.
        let (isOwed, held): (Bool, Set<CBUUID>?) = serialQueue.sync {
            if let unanswered = unansweredServicesRequests[key] {
                unansweredServicesRequests[key] =
                    unanswered > 1 ? unanswered - 1 : nil
            }
            guard let owed = owedServicesReplies[key], owed > 0 else {
                return (false, nil)
            }
            owedServicesReplies[key] = owed > 1 ? owed - 1 : nil
            guard owed == 1,
                let held = heldServicesRequests.removeValue(forKey: key),
                retrieveServicesCallbacks[key] != nil
            else { return (true, nil) }
            unansweredServicesRequests[key, default: 0] += 1
            return (true, held)
        }
        if isOwed {
            NSLog(
                "Dropped the services reply owed to a retrieveServices call that timed out: \(key)"
            )
            if let held = held {
                peripheral.discoverServices(held.isEmpty ? nil : Array(held))
            }
            return
        }
        if let error = error {
            NSLog("Error: \(error)")
            invokeAndClearDictionary(
                &retrieveServicesCallbacks,
                withKey: peripheral.uuidAsString(),
                usingParameters: [SwiftBleManager.errorPayload(error)]
            )
            return
        }
        if SwiftBleManager.verboseLogging {
            NSLog("Services Discover")
        }

        if abandonedDiscoveries.contains(key) {
            // This peripheral's last discovery was abandoned, as stale or
            // timed out. A services reply no pending call is waiting for
            // answers a request that was already settled. Another round of
            // requests would be traffic nobody waits for, and on a stale
            // table more replies for CoreBluetooth to route to the wrong
            // attribute.
            let isAwaited = serialQueue.sync {
                retrieveServicesCallbacks[key] != nil
            }
            guard isAwaited else { return }
            abandonedDiscoveries.remove(key)
        }

        let services = peripheral.safeServices
        if services.hasForeign {
            failRetrieveServicesForStaleGattCache(
                peripheral,
                location: "services",
                foreignClassNames: services.foreignClassNames
            )
            return
        }

        var servicesForPeripheral = Set<CBService>()
        servicesForPeripheral.formUnion(services.attributes)
        retrieveServicesLatches[peripheral.uuidAsString()] =
            servicesForPeripheral

        for service in services.attributes {
            if SwiftBleManager.verboseLogging {
                NSLog(
                    "Service \(service.uuid.uuidString) \(service.description)"
                )
            }
            if discoverIncludedServices {
                peripheral.discoverIncludedServices(nil, for: service)  // discover included services
            }
            peripheral.discoverCharacteristics(nil, for: service)  // discover characteristics for service
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverIncludedServicesFor service: CBService,
        error: Error?
    ) {
        if failIfForeignAttribute(
            service, expected: CBService.self, peripheral: peripheral,
            location: "included services"
        ) {
            return
        }
        if let error = error {
            NSLog("Error: \(error)")
            return
        }
        if abandonedDiscoveries.contains(peripheral.uuidAsString()) {
            return
        }
        peripheral.discoverCharacteristics(nil, for: service)  // discover characteristics for included service
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        if failIfForeignAttribute(
            service, expected: CBService.self, peripheral: peripheral,
            location: "characteristics"
        ) {
            return
        }
        if let error = error {
            NSLog("Error: \(error)")
        }
        if SwiftBleManager.verboseLogging {
            NSLog("Characteristics For Service Discover")
        }

        let peripheralUUIDString = peripheral.uuidAsString()
        let discovered = service.safeCharacteristics
        if error == nil && discovered.hasForeign {
            failRetrieveServicesForStaleGattCache(
                peripheral,
                location:
                    "characteristics of service \(service.uuid.uuidString)",
                foreignClassNames: discovered.foreignClassNames
            )
            return
        }
        let characteristics = (error == nil) ? discovered.attributes : []

        if characteristics.isEmpty {
            if var servicesLatch = retrieveServicesLatches[peripheralUUIDString] {
                servicesLatch.remove(service)
                retrieveServicesLatches[peripheralUUIDString] = servicesLatch

                if servicesLatch.isEmpty {
                    if failIfTreeHoldsForeignAttributes(peripheral) {
                        return
                    }
                    if let peripheral = peripherals[peripheralUUIDString] {
                        invokeAndClearDictionary(
                            &retrieveServicesCallbacks,
                            withKey: peripheralUUIDString,
                            usingParameters: [
                                NSNull(), peripheral.servicesInfo(),
                            ]
                        )
                    }
                    retrieveServicesLatches.removeValue(
                        forKey: peripheralUUIDString
                    )
                }
            }
            return
        }

        if abandonedDiscoveries.contains(peripheralUUIDString) {
            return
        }

        var characteristicsForService = Set<CBCharacteristic>()
        characteristicsForService.formUnion(characteristics)
        characteristicsLatches[service.uuid.uuidString] =
            characteristicsForService

        for characteristic in characteristics {
            peripheral.discoverDescriptors(for: characteristic)
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverDescriptorsFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if failIfForeignAttribute(
            characteristic, expected: CBCharacteristic.self,
            peripheral: peripheral, location: "descriptors"
        ) {
            return
        }
        if let error = error {
            NSLog("Error: \(error)")
        }
        let peripheralUUIDString: String = peripheral.uuidAsString()
        // CoreBluetooth declares the owning service weak and nullable, and it
        // can be gone by the time this event arrives, for example once the
        // attribute tree was invalidated. The event is ignored rather than
        // force-unwrapped, so the pending retrieveServices may not settle
        // until the peripheral disconnects or retrieveServicesTimeout runs
        // out.
        guard let owningService = characteristic.service else {
            NSLog(
                "Descriptors discovered for characteristic \(characteristic.uuid.uuidString) with no owning service; ignored"
            )
            return
        }
        let serviceUUIDString: String = owningService.uuid.uuidString

        if SwiftBleManager.verboseLogging {
            NSLog(
                "Descriptor For Characteristic Discover \(serviceUUIDString) \(characteristic.uuid.uuidString)"
            )
        }

        if var servicesLatch = retrieveServicesLatches[peripheralUUIDString],
            var characteristicsLatch = characteristicsLatches[serviceUUIDString]
        {

            characteristicsLatch.remove(characteristic)
            characteristicsLatches[serviceUUIDString] = characteristicsLatch

            if characteristicsLatch.isEmpty {
                // All characteristics for this service have been checked
                servicesLatch.remove(owningService)
                retrieveServicesLatches[peripheralUUIDString] = servicesLatch

                if servicesLatch.isEmpty {
                    // All characteristics and services have been checked
                    if failIfTreeHoldsForeignAttributes(peripheral) {
                        return
                    }
                    if let peripheral = peripherals[peripheral.uuidAsString()] {
                        invokeAndClearDictionary(
                            &retrieveServicesCallbacks,
                            withKey: peripheralUUIDString,
                            usingParameters: [
                                NSNull(), peripheral.servicesInfo(),
                            ]
                        )
                    }
                    characteristicsLatches.removeValue(
                        forKey: serviceUUIDString
                    )
                    retrieveServicesLatches.removeValue(
                        forKey: peripheralUUIDString
                    )
                }
            }

        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didReadRSSI RSSI: NSNumber,
        error: Error?
    ) {
        if SwiftBleManager.verboseLogging {
            print("didReadRSSI \(RSSI)")
        }

        if let error = error {
            invokeAndClearDictionary(
                &readRSSICallbacks,
                withKey: peripheral.uuidAsString(),
                usingParameters: [SwiftBleManager.errorPayload(error), RSSI]
            )
        } else {
            invokeAndClearDictionary(
                &readRSSICallbacks,
                withKey: peripheral.uuidAsString(),
                usingParameters: [NSNull(), RSSI]
            )
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor descriptor: CBDescriptor,
        error: Error?
    ) {
        let key = Helper.key(
            forPeripheral: peripheral,
            andCharacteristic: descriptor.characteristic!,
            andDescriptor: descriptor
        )

        if let error = error {
            NSLog(
                "Error reading descriptor value for \(descriptor.uuid) on characteristic \(descriptor.characteristic!.uuid) :\(error)"
            )
            invokeAndClearDictionary(
                &readDescriptorCallbacks,
                withKey: key,
                usingParameters: [SwiftBleManager.errorPayload(error), NSNull()]
            )
            return
        }

        if let descriptorValue = descriptor.value as? Data {
            NSLog(
                "Read value [descriptor: \(descriptor.uuid), characteristic: \(descriptor.characteristic!.uuid)]: (\(descriptorValue.count)) \(descriptorValue.hexadecimalString())"
            )
        } else {
            NSLog(
                "Read value [descriptor: \(descriptor.uuid), characteristic: \(descriptor.characteristic!.uuid)]: \(String(describing: descriptor.value))"
            )
        }

        if readDescriptorCallbacks[key] != nil {
            // The most future proof way of doing this that I could find, other option would be running strcmp on CBUUID strings
            // https://developer.apple.com/documentation/corebluetooth/cbuuid/characteristic_descriptors
            if let descriptorValue = descriptor.value as? Data {
                if SwiftBleManager.verboseLogging {
                    NSLog("Descriptor value is Data")
                }
                invokeAndClearDictionary(
                    &readDescriptorCallbacks,
                    withKey: key,
                    usingParameters: [NSNull(), descriptorValue.toArray()]
                )
            } else if let descriptorValue = descriptor.value as? NSNumber {
                if SwiftBleManager.verboseLogging {
                    NSLog("Descriptor value is NSNumber")
                }
                var value = descriptorValue.uint64Value
                let byteData = Data(
                    bytes: &value,
                    count: MemoryLayout.size(ofValue: value)
                )
                invokeAndClearDictionary(
                    &readDescriptorCallbacks,
                    withKey: key,
                    usingParameters: [NSNull(), byteData.toArray()]
                )
            } else if let descriptorValue = descriptor.value as? String {
                if SwiftBleManager.verboseLogging {
                    NSLog("Descriptor value is String")
                }
                if let byteData = descriptorValue.data(using: .utf8) {
                    invokeAndClearDictionary(
                        &readDescriptorCallbacks,
                        withKey: key,
                        usingParameters: [NSNull(), byteData.toArray()]
                    )
                }
            } else {
                NSLog(
                    "Unrecognized type of descriptor: (UUID: \(descriptor.uuid), value type: \(type(of: descriptor.value)), value: \(String(describing: descriptor.value)))"
                )
                if let descriptorValue = descriptor.value as? Data {
                    invokeAndClearDictionary(
                        &readDescriptorCallbacks,
                        withKey: key,
                        usingParameters: [NSNull(), descriptorValue.toArray()]
                    )
                }
            }
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        let key = Helper.key(
            forPeripheral: peripheral,
            andCharacteristic: characteristic
        )

        if let error = error {
            NSLog("Error \(characteristic.uuid) :\(error)")
            invokeAndClearDictionary(
                &readCallbacks,
                withKey: key,
                usingParameters: [SwiftBleManager.errorPayload(error), NSNull()]
            )
            return
        }

        if SwiftBleManager.verboseLogging, let value = characteristic.value {
            NSLog(
                "Read value [\(characteristic.uuid)]: \( value.hexadecimalString())"
            )
        }

        serialQueue.sync {
            if readCallbacks[key] != nil {
                invokeAndClearDictionary_THREAD_UNSAFE(
                    &readCallbacks,
                    withKey: key,
                    usingParameters: [
                        NSNull(), characteristic.value!.toArray(),
                    ]
                )
            } else {
                guard let bufferContainer = self.bufferedCharacteristics[key]
                else {
                    // Standard notification
                    self.bleManager?.emitOnDidUpdateValue(forCharacteristic: [
                        "peripheral": peripheral.uuidAsString(),
                        "characteristic": characteristic.uuid.uuidString
                            .lowercased(),
                        "service": characteristic.service!.uuid.uuidString
                            .lowercased(),
                        "value": characteristic.value!.toArray(),
                    ])
                    return
                }

                // Notification with buffer
                var valueToEmit: Data = characteristic.value!
                while !valueToEmit.isEmpty {
                    let rest = bufferContainer.put(valueToEmit)
                    if bufferContainer.isBufferFull {
                        self.bleManager?.emitOnDidUpdateValue(
                            forCharacteristic: [
                                "peripheral": peripheral.uuidAsString(),
                                "characteristic": characteristic.uuid.uuidString
                                    .lowercased(),
                                "service": characteristic.service!.uuid
                                    .uuidString.lowercased(),
                                "value": bufferContainer.items.toArray(),
                            ])
                        bufferContainer.resetBuffer()
                    }

                    valueToEmit = rest
                }
            }
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error = error {
            NSLog(
                "Error in didUpdateNotificationStateForCharacteristic: \(error)"
            )

            // Remove any buffered data if notification was started with buffer
            let key = Helper.key(
                forPeripheral: peripheral,
                andCharacteristic: characteristic
            )
            self.bufferedCharacteristics.removeValue(forKey: key)

            self.bleManager?.emitOnDidUpdateNotificationState(for: [
                "peripheral": peripheral.uuidAsString(),
                "characteristic": characteristic.uuid.uuidString.lowercased(),
                "isNotifying": false,
                "domain": error._domain,
                "code": error._code,
            ])
        } else {
            self.bleManager?.emitOnDidUpdateNotificationState(for: [
                "peripheral": peripheral.uuidAsString(),
                "characteristic": characteristic.uuid.uuidString.lowercased(),
                "isNotifying": characteristic.isNotifying,
            ])
        }

        let key = Helper.key(
            forPeripheral: peripheral,
            andCharacteristic: characteristic
        )

        if let error = error {
            if notificationCallbacks[key] != nil {
                invokeAndClearDictionary(
                    &notificationCallbacks,
                    withKey: key,
                    usingParameters: [error]
                )
            }
            if stopNotificationCallbacks[key] != nil {
                invokeAndClearDictionary(
                    &stopNotificationCallbacks,
                    withKey: key,
                    usingParameters: [error]
                )
            }
        } else {
            if characteristic.isNotifying {
                if SwiftBleManager.verboseLogging {
                    NSLog("Notification began on \(characteristic.uuid)")
                }
                if notificationCallbacks[key] != nil {
                    invokeAndClearDictionary(
                        &notificationCallbacks,
                        withKey: key,
                        usingParameters: []
                    )
                }
            } else {
                // Notification has stopped
                if SwiftBleManager.verboseLogging {
                    NSLog("Notification ended on \(characteristic.uuid)")
                }
                if stopNotificationCallbacks[key] != nil {
                    invokeAndClearDictionary(
                        &stopNotificationCallbacks,
                        withKey: key,
                        usingParameters: []
                    )
                }
            }
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor descriptor: CBDescriptor,
        error: Error?
    ) {
        NSLog("didWrite descriptor")

        let key = Helper.key(
            forPeripheral: peripheral,
            andCharacteristic: descriptor.characteristic!,
            andDescriptor: descriptor
        )
        let callbacks = writeDescriptorCallbacks[key]
        if callbacks != nil {
            if let error = error {
                NSLog("\(error)")
                invokeAndClearDictionary(
                    &writeDescriptorCallbacks,
                    withKey: key,
                    usingParameters: [SwiftBleManager.errorPayload(error)]
                )
            } else {
                invokeAndClearDictionary(
                    &writeDescriptorCallbacks,
                    withKey: key,
                    usingParameters: []
                )
            }
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        NSLog("didWrite")

        let key = Helper.key(
            forPeripheral: peripheral,
            andCharacteristic: characteristic
        )
        let peripheralWriteCallbacks = writeCallbacks[key]

        if peripheralWriteCallbacks != nil {
            if let error = error {
                NSLog("\(error)")
                invokeAndClearDictionary(
                    &writeCallbacks,
                    withKey: key,
                    usingParameters: [SwiftBleManager.errorPayload(error)]
                )
                serialQueue.sync {
                    writeQueues.removeValue(forKey: key)
                }
            } else {
                if let message = dequeueNextSplitMessage(forKey: key) {
                    NSLog("Message to write \(message.hexadecimalString())")
                    peripheral.writeValue(
                        message,
                        for: characteristic,
                        type: .withResponse
                    )
                } else {
                    invokeAndClearDictionary(
                        &writeCallbacks,
                        withKey: key,
                        usingParameters: []
                    )
                }
            }
        }
    }

    @objc public static func getCentralManager() -> CBCentralManager? {
        return sharedManager
    }

    @objc public static func getInstance() -> SwiftBleManager? {
        return shared
    }

    @objc public func enableBluetooth(
        _ callback: @escaping RCTResponseSenderBlock
    ) {
        callback(["Not supported"])
    }

    @objc public func getBondedPeripherals(
        _ callback: @escaping RCTResponseSenderBlock
    ) {
        callback(["Not supported"])
    }

    @objc public func createBond(
        _ peripheralUUID: String,
        devicePin: String,
        callback: @escaping RCTResponseSenderBlock
    ) {
        callback(["Not supported"])
    }

    @objc public func removeBond(
        _ peripheralUUID: String,
        callback: @escaping RCTResponseSenderBlock
    ) {
        callback(["Not supported"])
    }

    @objc public func removePeripheral(
        _ peripheralUUID: String,
        callback: @escaping RCTResponseSenderBlock
    ) {
        callback(["Not supported"])
    }

    @objc public func requestMTU(
        _ peripheralUUID: String,
        mtu: Int,
        callback: @escaping RCTResponseSenderBlock
    ) {
        callback(["Not supported"])
    }

    @objc public func requestConnectionPriority(
        _ peripheralUUID: String,
        connectionPriority: Int,
        callback: @escaping RCTResponseSenderBlock
    ) {
        callback(["Not supported"])
    }

    @objc public func refreshCache(
        _ peripheralUUID: String,
        callback: @escaping RCTResponseSenderBlock
    ) {
        callback(["Not supported"])
    }

    @objc public func setName(_ name: String) {
        // Not supported
    }

    @objc public func getAssociatedPeripherals(
        _ callback: @escaping RCTResponseSenderBlock
    ) {
        callback(["Not supported"])
    }

    @objc public func removeAssociatedPeripheral(
        _ peripheralUUID: String,
        callback: @escaping RCTResponseSenderBlock
    ) {
        callback(["Not supported"])
    }

    @objc public func supportsCompanion(
        _ callback: @escaping RCTResponseSenderBlock
    ) {
        callback([NSNull(), false])
    }

    @objc public func companionScan(
        _ serviceUUIDs: [Any],
        option: NSDictionary,
        callback: RCTResponseSenderBlock
    ) {
        callback(["Not supported"])
    }
}
