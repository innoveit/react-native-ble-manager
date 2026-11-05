#if canImport(AccessorySetupKit) && !targetEnvironment(macCatalyst)
import AccessorySetupKit
import CoreBluetooth
import UIKit

@available(iOS 18.0, *)
final class AccessorySetup {
    private var session: ASAccessorySession?
    private var resolve: RCTPromiseResolveBlock?
    private var reject: RCTPromiseRejectBlock?
    private var scanning = false

    deinit {
        let session = session
        DispatchQueue.main.async { session?.invalidate() }
    }

    private func payload(_ accessory: ASAccessory) -> [String: Any]? {
        guard let id = accessory.bluetoothIdentifier else { return nil }
        return [
            "id": id.uuidString.lowercased(),
            "name": accessory.displayName,
            "state": accessory.state.rawValue,
        ]
    }

    private func finish(_ value: Any? = nil, code: String? = nil, error: Error? = nil) {
        dispatchPrecondition(condition: .onQueue(.main))
        let resolve = resolve
        let reject = reject
        let session = session
        self.resolve = nil
        self.reject = nil
        self.session = nil
        scanning = false
        session?.invalidate()
        if let code {
            reject?(code, error?.localizedDescription ?? code, error)
        } else {
            resolve?(value)
        }
    }

    private func perform(
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock,
        scanning: Bool = false,
        onEvent: @escaping (ASAccessoryEvent) -> Void = { _ in },
        action: @escaping (ASAccessorySession) -> Void
    ) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard session == nil else {
            reject("ACCESSORY_SETUP_BUSY", "Another accessory operation is in progress.", nil)
            return
        }
        guard let technologies = Bundle.main.object(forInfoDictionaryKey: "NSAccessorySetupKitSupports") as? [String],
            technologies.contains("Bluetooth")
        else {
            reject("INVALID_ACCESSORY_SETUP", "Declare Bluetooth in NSAccessorySetupKitSupports in Info.plist.", nil)
            return
        }
        let session = ASAccessorySession()
        self.session = session
        self.resolve = resolve
        self.reject = reject
        self.scanning = scanning
        session.activate(on: .main) { [weak self, weak session] event in
            guard let self, let session, self.session === session else { return }
            if let error = event.error {
                self.finish(code: "ACCESSORY_SETUP_FAILED", error: error)
                return
            }
            switch event.eventType {
            case .activated:
                action(session)
            case .invalidated:
                self.finish(code: "SESSION_INVALIDATED")
            case .pickerSetupFailed:
                self.finish(code: "ACCESSORY_SETUP_FAILED")
            default:
                onEvent(event)
            }
        }
    }

    func scan(
        _ displayItems: [Any],
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !displayItems.isEmpty else {
            reject("INVALID_DISPLAY_ITEMS", "Provide at least one accessory display item.", nil)
            return
        }
        let bundle = Bundle.main
        guard let services = bundle.object(forInfoDictionaryKey: "NSAccessorySetupBluetoothServices") as? [String],
            services.allSatisfy({ Helper.isValidBLEUUID($0) })
        else {
            reject("INVALID_ACCESSORY_SETUP", "Declare valid UUIDs in NSAccessorySetupBluetoothServices in Info.plist.", nil)
            return
        }
        let allowedServices = services.map { CBUUID(string: $0) }
        var items: [ASPickerDisplayItem] = []
        for value in displayItems {
            guard let item = value as? [String: Any],
                let name = item["name"] as? String, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                let imageName = item["productImage"] as? String,
                let image = UIImage(named: imageName) ?? UIImage(systemName: imageName),
                let service = item["serviceUUID"] as? String, Helper.isValidBLEUUID(service)
            else {
                reject("INVALID_DISPLAY_ITEM", "Each item needs a name, a bundled image or SF Symbol, and a valid serviceUUID.", nil)
                return
            }
            let uuid = CBUUID(string: service)
            guard allowedServices.contains(uuid) else {
                reject("INVALID_SERVICE_UUID", "Declare service \(service) in NSAccessorySetupBluetoothServices in Info.plist.", nil)
                return
            }
            let descriptor = ASDiscoveryDescriptor()
            descriptor.bluetoothServiceUUID = uuid
            items.append(ASPickerDisplayItem(name: name, productImage: image, descriptor: descriptor))
        }

        var selected: [UUID: ASAccessory] = [:]
        perform(resolve: resolve, reject: reject, scanning: true, onEvent: { [weak self] event in
            guard let self else { return }
            switch event.eventType {
            case .accessoryAdded:
                if let accessory = event.accessory, let id = accessory.bluetoothIdentifier {
                    selected[id] = accessory
                }
            case .accessoryChanged:
                if let accessory = event.accessory, let id = accessory.bluetoothIdentifier, selected[id] != nil {
                    selected[id] = accessory
                }
            case .accessoryRemoved:
                if let id = event.accessory?.bluetoothIdentifier {
                    selected.removeValue(forKey: id)
                }
            case .pickerDidDismiss:
                self.finish(selected.values.compactMap { self.payload($0) })
            default:
                break
            }
        }) { [weak self] session in
            session.showPicker(for: items) { [weak self, weak session] error in
                DispatchQueue.main.async {
                    guard let self, let session, self.session === session, let error else { return }
                    self.finish(code: "ACCESSORY_SETUP_FAILED", error: error)
                }
            }
        }
    }

    func getPairedAccessories(
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        perform(resolve: resolve, reject: reject) { [weak self] session in
            guard let self else { return }
            self.finish(session.accessories.compactMap { self.payload($0) })
        }
    }

    func remove(
        _ id: String,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        guard let uuid = UUID(uuidString: id) else {
            reject("INVALID_ACCESSORY_ID", "Expected a Bluetooth accessory UUID.", nil)
            return
        }
        perform(resolve: resolve, reject: reject) { [weak self] session in
            guard let self else { return }
            guard let accessory = session.accessories.first(where: { $0.bluetoothIdentifier == uuid }) else {
                self.finish(code: "ACCESSORY_NOT_FOUND")
                return
            }
            session.removeAccessory(accessory) { [weak self, weak session] error in
                DispatchQueue.main.async {
                    guard let self, let session, self.session === session else { return }
                    self.finish(code: error == nil ? nil : "COULD_NOT_REMOVE_ACCESSORY", error: error)
                }
            }
        }
    }

    func stopScan() {
        if scanning { cancel() }
    }

    func cancel() {
        if session != nil { finish(code: "CANCELLED") }
    }
}
#endif
