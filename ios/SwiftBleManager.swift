import CoreBluetooth
import Foundation

@objc
public class SwiftBleManager: NSObject, CBCentralManagerDelegate,
    CBPeripheralDelegate
{
    static var shared: SwiftBleManager?
    static var sharedManager: CBCentralManager?

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

    private let serialQueue = DispatchQueue(label: "BleManager.serialQueue")

    private var exactAdvertisingName: [String]

    static var verboseLogging = false

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
            }
        } else {
            manager = CBCentralManager(
                delegate: self,
                queue: queue,
                options: initOptions
            )
            SwiftBleManager.sharedManager = manager
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
        if let serviceUUIDStrings = scanningOptions["serviceUUIDStrings"]
            as? [String]
        {
            serviceUUIDs = serviceUUIDStrings.map { CBUUID(string: $0) }
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

            if let services = peripheral.instance.services {
                for service in services {
                    if let characteristics = service.characteristics {
                        for characteristic in characteristics {
                            if characteristic.isNotifying {
                                NSLog(
                                    "Remove notification from: \(characteristic.uuid)"
                                )
                                peripheral.instance.setNotifyValue(
                                    false,
                                    for: characteristic
                                )
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

    @objc public func retrieveServices(
        _ peripheralUUID: String,
        services: [String],
        callback: @escaping RCTResponseSenderBlock
    ) {
        NSLog("retrieveServices \(services)")

        if let peripheral = peripherals[peripheralUUID],
            peripheral.instance.state == .connected
        {
            insertCallback(
                callback,
                intoDictionary: &retrieveServicesCallbacks,
                withKey: peripheral.instance.uuidAsString()
            )

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
        let errorStr =
            "Peripheral connection failure: \(peripheral.uuidAsString() ) (\(error?.localizedDescription ?? "")"
        NSLog(errorStr)

        invokeAndClearDictionary(
            &connectCallbacks,
            withKey: peripheral.uuidAsString(),
            usingParameters: [errorStr]
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

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {
        if let error = error {
            NSLog("Error: \(error)")
            return
        }
        if SwiftBleManager.verboseLogging {
            NSLog("Services Discover")
        }

        var servicesForPeripheral = Set<CBService>()
        servicesForPeripheral.formUnion(peripheral.services ?? [])
        retrieveServicesLatches[peripheral.uuidAsString()] =
            servicesForPeripheral

        if let services = peripheral.services {
            for service in services {
                if SwiftBleManager.verboseLogging {
                    NSLog(
                        "Service \(service.uuid.uuidString) \(service.description)"
                    )
                }
                peripheral.discoverIncludedServices(nil, for: service)  // discover included services
                peripheral.discoverCharacteristics(nil, for: service)  // discover characteristics for service
            }
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverIncludedServicesFor service: CBService,
        error: Error?
    ) {
        if let error = error {
            NSLog("Error: \(error)")
            return
        }
        peripheral.discoverCharacteristics(nil, for: service)  // discover characteristics for included service
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        if let error = error {
            NSLog("Error: \(error)")
            return
        }
        if SwiftBleManager.verboseLogging {
            NSLog("Characteristics For Service Discover")
        }

        var characteristicsForService = Set<CBCharacteristic>()
        characteristicsForService.formUnion(service.characteristics ?? [])
        characteristicsLatches[service.uuid.uuidString] =
            characteristicsForService

        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                peripheral.discoverDescriptors(for: characteristic)
            }
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverDescriptorsFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error = error {
            NSLog("Error: \(error)")
            return
        }
        let peripheralUUIDString: String = peripheral.uuidAsString()
        let serviceUUIDString: String =
            (characteristic.service?.uuid.uuidString)!

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
                servicesLatch.remove(characteristic.service!)
                retrieveServicesLatches[peripheralUUIDString] = servicesLatch

                if servicesLatch.isEmpty {
                    // All characteristics and services have been checked
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
                usingParameters: [error.localizedDescription, RSSI]
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
                usingParameters: [error.localizedDescription, NSNull()]
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
                usingParameters: [error.localizedDescription, NSNull()]
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
                    usingParameters: [error.localizedDescription]
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
                    usingParameters: [error.localizedDescription]
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
