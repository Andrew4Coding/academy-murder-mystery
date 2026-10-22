import Foundation
import Synchronization

protocol HostClock: Sendable {
    var now: Date { get }
}

struct SystemHostClock: HostClock {
    var now: Date {
        Date()
    }
}

final class ManualHostClock: HostClock {
    private let current: Mutex<Date>

    init(_ start: Date) {
        current = Mutex(start)
    }

    var now: Date {
        current.withLock { $0 }
    }

    func set(_ date: Date) {
        current.withLock { $0 = date }
    }

    func advance(by seconds: TimeInterval) {
        current.withLock { $0 = $0.addingTimeInterval(seconds) }
    }
}

final class ScaledHostClock: HostClock {
    private struct Anchor {
        var real: Date
        var virtual: Date
        var speed: Double
    }

    private let anchor: Mutex<Anchor>

    init(start: Date = Date(), speed: Double = 1) {
        anchor = Mutex(Anchor(real: Date(), virtual: start, speed: speed))
    }

    var now: Date {
        anchor.withLock { $0.virtual.addingTimeInterval(Date().timeIntervalSince($0.real) * $0.speed) }
    }

    var speed: Double {
        anchor.withLock { $0.speed }
    }

    func setSpeed(_ speed: Double) {
        anchor.withLock { current in
            let nowReal = Date()
            current.virtual = current.virtual.addingTimeInterval(nowReal.timeIntervalSince(current.real) * current.speed)
            current.real = nowReal
            current.speed = speed
        }
    }
}
