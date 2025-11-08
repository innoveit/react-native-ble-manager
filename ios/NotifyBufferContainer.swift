import Foundation

class NotifyBufferContainer {
    public var items: Data
    public let capacity: Int

    public var count: Int {
        items.count
    }

    public var remaining: Int {
        capacity - items.count
    }

    public var isBufferFull: Bool {
        items.count >= capacity
    }

    init(size: Int) {
        self.capacity = size
        self.items = Data(capacity: size)
    }

    public func resetBuffer() {
        items.removeAll(keepingCapacity: true)
    }

    public func put(_ value: Data) -> Data {
        let remainingCapacity = self.remaining
        guard remainingCapacity > 0 else { return value }

        let restLength = value.count - remainingCapacity

        let toInsert: Data
        let rest: Data
        if restLength > 0 {
            toInsert = value.prefix(remainingCapacity)
            rest = value.suffix(restLength)
        } else {
            toInsert = value
            rest = Data()
        }
        items.append(toInsert)

        return rest
    }
}
