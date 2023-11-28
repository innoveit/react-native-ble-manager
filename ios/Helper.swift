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
            return "poweredOff"
        case .poweredOn:
            return "poweredOn"
        @unknown default:
            return "unknown"
        }
    }
    
    static func dataToArrayBuffer(_ data: Data) -> [String: Any] {
        return [
            "CDVType": "ArrayBuffer",
            "data": data.base64EncodedString(options: []),
            "bytes": data.map { $0 }
        ]
    }
    
    static func reformatAdvertisementData(_ advertisementData: [String:Any]) -> [String:Any] {
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
        if let serviceData = adv[CBAdvertisementDataServiceDataKey] as? NSMutableDictionary {
            for (key, value) in serviceData {
                if let uuidKey = key as? CBUUID, let dataValue = value as? Data {
                    serviceData.removeObject(forKey: uuidKey)
                    serviceData[uuidKey.uuidString.lowercased()] = Helper.dataToArrayBuffer(dataValue)
                }
            }
            
            adv.removeValue(forKey: CBAdvertisementDataServiceDataKey)
            adv["serviceData"] = serviceData
        }
        
        // Create a new list of Service UUIDs as Strings instead of CBUUIDs
        if let serviceUUIDs = adv[CBAdvertisementDataServiceUUIDsKey] as? NSMutableArray {
            var serviceUUIDStrings:Array<String> = []
            for value in serviceUUIDs {
                if let uuid = value as? CBUUID {
                    serviceUUIDStrings.append(uuid.uuidString.lowercased())
                }
            }
            
            adv.removeValue(forKey: CBAdvertisementDataServiceUUIDsKey)
            adv["serviceUUIDs"] = serviceUUIDStrings
        }
        
        return adv
    }
}

class Peripheral:Hashable {
    var peripheral: CBPeripheral
    var rssi: NSNumber?
    var advertisementData: [String:Any]?
    
    init(peripheral: CBPeripheral, rssi: NSNumber? = nil, advertisementData: [String:Any]? = nil) {
        self.peripheral = peripheral
        self.rssi = rssi
        if let adv = advertisementData {
            self.advertisementData = Helper.reformatAdvertisementData(adv)
        }
    }
    
    func setRSSI(_ newRSSI: NSNumber?) {
        self.rssi = newRSSI
    }
    
    func setAdvertisementData(_ advertisementData: [String:Any]) {
        self.advertisementData = advertisementData
    }
    
    func advertisingInfo() -> NSDictionary {
        var peripheralInfo: [String: Any] = [:]
        
        peripheralInfo["name"] = peripheral.name
        peripheralInfo["id"] = peripheral.identifier.uuidString.lowercased()
        peripheralInfo["rssi"] = self.rssi
        peripheralInfo["advertising"] = self.advertisementData
        
        return NSDictionary(dictionary: peripheralInfo)
    }
    
    static func == (lhs: Peripheral, rhs: Peripheral) -> Bool {
        return lhs.peripheral == rhs.peripheral
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(peripheral)
    }
}
