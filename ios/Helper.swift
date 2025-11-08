import Foundation

class Helper {
    static func centralManagerStateToString(_ state: CBManagerState) -> String {
        switch state {
        case .unknown:
            return "unknown"
        case .resetting:
            return "resetting"
        case .unsupported:
            return "unsupported"
        case .unauthorized:
            return "unauthorized"
        case .poweredOff:
            return "off"
        case .poweredOn:
            return "on"
        @unknown default:
            return "unknown"
        }
    }

    static func dataToArrayBuffer(_ data: Data) -> [String: Any] {
        return [
            "CDVType": "ArrayBuffer",
            "data": data.base64EncodedString(options: []),
            "bytes": data.map { $0 },
        ]
    }

    static func reformatAdvertisementData(_ advertisementData: [String: Any])
        -> [String: Any]
    {
        var adv = advertisementData
        // Rename 'local name' key
        if let localName = adv[CBAdvertisementDataLocalNameKey] {
            adv.removeValue(forKey: CBAdvertisementDataLocalNameKey)
            adv["localName"] = localName
        }

        // Rename 'isConnectable' key
        if let isConnectable = adv[CBAdvertisementDataIsConnectable] {
            adv.removeValue(forKey: CBAdvertisementDataIsConnectable)
            adv["isConnectable"] = isConnectable
        }

        // Rename 'power level' key
        if let powerLevel = adv[CBAdvertisementDataTxPowerLevelKey] {
            adv.removeValue(forKey: CBAdvertisementDataTxPowerLevelKey)
            adv["txPowerLevel"] = powerLevel
        }

        // Service Data is a dictionary of CBUUID and NSData
        // Convert to String keys with Array Buffer values
        if let serviceData = adv[CBAdvertisementDataServiceDataKey]
            as? NSMutableDictionary
        {
            for (key, value) in serviceData {
                if let uuidKey = key as? CBUUID, let dataValue = value as? Data
                {
                    serviceData.removeObject(forKey: uuidKey)
                    serviceData[uuidKey.uuidString.lowercased()] =
                        Helper.dataToArrayBuffer(dataValue)
                }
            }

            adv.removeValue(forKey: CBAdvertisementDataServiceDataKey)
            adv["serviceData"] = serviceData
        }

        // Create a new list of Service UUIDs as Strings instead of CBUUIDs
        if let serviceUUIDs = adv[CBAdvertisementDataServiceUUIDsKey]
            as? NSMutableArray
        {
            var serviceUUIDStrings: [String] = []
            for value in serviceUUIDs {
                if let uuid = value as? CBUUID {
                    serviceUUIDStrings.append(uuid.uuidString.lowercased())
                }
            }

            adv.removeValue(forKey: CBAdvertisementDataServiceUUIDsKey)
            adv["serviceUUIDs"] = serviceUUIDStrings
        }
        // Solicited Services UUIDs is an array of CBUUIDs, convert into Strings
        if let solicitiedServiceUUIDs = adv[
            CBAdvertisementDataSolicitedServiceUUIDsKey
        ] as? NSMutableArray {
            var solicitiedServiceUUIDStrings: [String] = []
            for value in solicitiedServiceUUIDs {
                if let uuid = value as? CBUUID {
                    solicitiedServiceUUIDStrings.append(
                        uuid.uuidString.lowercased()
                    )
                }
            }

            adv.removeValue(forKey: CBAdvertisementDataSolicitedServiceUUIDsKey)
            adv["solicitedServiceUUIDs"] = solicitiedServiceUUIDStrings
        }

        // Overflow Services UUIDs is an array of CBUUIDs, convert into Strings
        if let overflowServiceUUIDs = adv[
            CBAdvertisementDataOverflowServiceUUIDsKey
        ] as? NSMutableArray {
            var overflowServiceUUIDStrings: [String] = []
            for value in overflowServiceUUIDs {
                if let uuid = value as? CBUUID {
                    overflowServiceUUIDStrings.append(
                        uuid.uuidString.lowercased()
                    )
                }
            }

            adv.removeValue(forKey: CBAdvertisementDataOverflowServiceUUIDsKey)
            adv["overflowServiceUUIDs"] = overflowServiceUUIDStrings
        }

        // Convert the manufacturer data
        if let mfgData = adv[CBAdvertisementDataManufacturerDataKey] as? Data {
            if mfgData.count > 1 {
                let manufactureID = UInt16(mfgData[0]) + UInt16(mfgData[1]) << 8
                var manInfo: [String: Any] = [:]
                manInfo[String(format: "%04x", manufactureID)] =
                    Helper.dataToArrayBuffer(
                        mfgData.subdata(in: 2..<mfgData.endIndex)
                    )
                adv["manufacturerData"] = manInfo
            }
            adv.removeValue(forKey: CBAdvertisementDataManufacturerDataKey)
            adv["manufacturerRawData"] = Helper.dataToArrayBuffer(mfgData)

        }

        return adv
    }

    static func decodeCharacteristicProperties(_ p: CBCharacteristicProperties)
        -> [String: Any]
    {
        var props: [String: Any] = [:]

        // NOTE: props strings need to be consistent across iOS and Android
        if p.contains(.broadcast) {
            props["Broadcast"] = "Broadcast"
        }

        if p.contains(.read) {
            props["Read"] = "Read"
        }

        if p.contains(.writeWithoutResponse) {
            props["WriteWithoutResponse"] = "WriteWithoutResponse"
        }

        if p.contains(.write) {
            props["Write"] = "Write"
        }

        if p.contains(.notify) {
            props["Notify"] = "Notify"
        }

        if p.contains(.indicate) {
            props["Indicate"] = "Indicate"
        }

        if p.contains(.authenticatedSignedWrites) {
            props["AuthenticateSignedWrites"] = "AuthenticateSignedWrites"
        }

        if p.contains(.extendedProperties) {
            props["ExtendedProperties"] = "ExtendedProperties"
        }

        if p.contains(.notifyEncryptionRequired) {
            props["NotifyEncryptionRequired"] = "NotifyEncryptionRequired"
        }

        if p.contains(.indicateEncryptionRequired) {
            props["IndicateEncryptionRequired"] = "IndicateEncryptionRequired"
        }

        return props
    }

    static func key(
        forPeripheral peripheral: CBPeripheral,
        andCharacteristic characteristic: CBCharacteristic
    ) -> String {
        return
            "\(String(describing: peripheral.uuidAsString()))|\(characteristic.uuid)"
    }

    static func key(
        forPeripheral peripheral: CBPeripheral,
        andCharacteristic characteristic: CBCharacteristic,
        andDescriptor descriptor: CBDescriptor
    ) -> String {
        return
            "\(String(describing: peripheral.uuidAsString()))|\(characteristic.uuid)|\(descriptor.uuid)"
    }

    static func findDescriptor(
        fromUUID UUID: CBUUID,
        characteristic: CBCharacteristic
    ) -> CBDescriptor? {
        if SwiftBleManager.verboseLogging {
            NSLog(
                "Looking for descriptor \(UUID) on characteristic \(characteristic.uuid)"
            )
        }
        for descriptor in characteristic.descriptors ?? [] {
            if descriptor.uuid.isEqual(UUID) {
                if SwiftBleManager.verboseLogging {
                    NSLog("Found descriptor \(UUID)")
                }
                return descriptor
            }
        }
        return nil  // Descriptor not found on this characteristic
    }

    // Find a service in a peripheral
    static func findService(fromUUID UUID: CBUUID, peripheral p: CBPeripheral)
        -> CBService?
    {
        for service in p.services ?? [] {
            if service.uuid.isEqual(UUID) {
                return service
            }
        }

        return nil  // Service not found on this peripheral
    }

    // Find a characteristic in service with a specific property
    static func findCharacteristic(
        fromUUID UUID: CBUUID,
        service: CBService,
        prop: CBCharacteristicProperties
    ) -> CBCharacteristic? {
        if SwiftBleManager.verboseLogging {
            NSLog("Looking for \(UUID) with properties \(prop.rawValue)")
        }
        for characteristic in service.characteristics ?? [] {
            if characteristic.properties.contains(prop)
                && characteristic.uuid.isEqual(UUID)
            {
                if SwiftBleManager.verboseLogging {
                    NSLog("Found \(UUID)")
                }
                return characteristic
            }
        }
        return nil  // Characteristic with prop not found on this service
    }

    // Find a characteristic in service by UUID
    static func findCharacteristic(fromUUID UUID: CBUUID, service: CBService)
        -> CBCharacteristic?
    {
        if SwiftBleManager.verboseLogging {
            NSLog("Looking for \(UUID)")
        }
        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid.isEqual(UUID) {
                if SwiftBleManager.verboseLogging {
                    NSLog("Found \(UUID)")
                }
                return characteristic
            }
        }
        return nil  // Characteristic not found on this service
    }

}

class Peripheral: Hashable {
    var instance: CBPeripheral
    var rssi: NSNumber?
    var advertisementData: [String: Any]?

    init(
        peripheral: CBPeripheral,
        rssi: NSNumber? = nil,
        advertisementData: [String: Any]? = nil
    ) {
        self.instance = peripheral
        self.rssi = rssi
        self.advertisementData = advertisementData
    }

    func setRSSI(_ newRSSI: NSNumber?) {
        self.rssi = newRSSI
    }

    func setAdvertisementData(_ advertisementData: [String: Any]) {
        self.advertisementData = advertisementData
    }

    func advertisingInfo() -> [String: Any] {
        var peripheralInfo: [String: Any] = [:]

        peripheralInfo["name"] = instance.name
        peripheralInfo["id"] = instance.uuidAsString()
        peripheralInfo["rssi"] = self.rssi
        if let adv = self.advertisementData {
            peripheralInfo["advertising"] = Helper.reformatAdvertisementData(
                adv
            )
        }

        return peripheralInfo
    }

    func servicesInfo() -> [String: Any] {
        var servicesInfo: [String: Any] = advertisingInfo()

        var serviceList = [[String: Any]]()
        var characteristicList = [[String: Any]]()

        for service in instance.services ?? [] {
            var serviceDictionary = [String: Any]()
            serviceDictionary["uuid"] = service.uuid.uuidString.lowercased()
            serviceList.append(serviceDictionary)

            for characteristic in service.characteristics ?? [] {
                var characteristicDictionary = [String: Any]()
                characteristicDictionary["service"] = service.uuid.uuidString
                    .lowercased()
                characteristicDictionary["characteristic"] = characteristic.uuid
                    .uuidString.lowercased()

                if let value = characteristic.value, value.count > 0 {
                    characteristicDictionary["value"] =
                        Helper.dataToArrayBuffer(value)
                }

                characteristicDictionary["properties"] =
                    Helper.decodeCharacteristicProperties(
                        characteristic.properties
                    )

                characteristicDictionary["isNotifying"] =
                    characteristic.isNotifying

                var descriptorList = [[String: Any]]()
                for descriptor in characteristic.descriptors ?? [] {
                    var descriptorDictionary = [String: Any]()
                    descriptorDictionary["uuid"] = descriptor.uuid.uuidString
                        .lowercased()

                    if let value = descriptor.value {
                        descriptorDictionary["value"] = value
                    }

                    descriptorList.append(descriptorDictionary)
                }

                if descriptorList.count > 0 {
                    characteristicDictionary["descriptors"] = descriptorList
                }

                characteristicList.append(characteristicDictionary)
            }
        }

        servicesInfo["services"] = serviceList
        servicesInfo["characteristics"] = characteristicList

        return servicesInfo
    }

    static func == (lhs: Peripheral, rhs: Peripheral) -> Bool {
        return lhs.instance.uuidAsString() == rhs.instance.uuidAsString()
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(instance.uuidAsString())
    }
}

class BLECommandContext: NSObject {
    var peripheral: Peripheral?
    var service: CBService?
    var characteristic: CBCharacteristic?
}

extension Data {
    func hexadecimalString() -> String {
        /* Returns hexadecimal string of Data. Empty string if data is empty. */
        if self.isEmpty {
            return ""
        }
        return map { "0x" + String(format: "%02hhx", $0) }.joined(
            separator: " "
        )
    }

    func toArray() -> [NSNumber] {
        /* Returns an array of NSNumber representing the hexadecimal values of the bytes in the data. Empty array if data is empty. */

        let dataBuffer = [UInt8](self)

        if dataBuffer.isEmpty {
            return []
        }

        return dataBuffer.map { NSNumber(value: $0) }
    }
}

extension CBPeripheral {

    func uuidAsString() -> String {
        return self.identifier.uuidString.lowercased()
    }
}
