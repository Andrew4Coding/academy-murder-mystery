import CoreBluetooth
import Observation

@MainActor @Observable
final class ProximityService: NSObject {
    static let serviceUUID = CBUUID(string: "6A1C0B5E-3F6E-4C1A-9B2B-3A1F5D7C9E01")

    private struct Reading {
        var rssi: Double
        var lastSeen: Date
    }

    private(set) var bluetoothState: CBManagerState = .unknown

    @ObservationIgnored private var central: CBCentralManager?
    @ObservationIgnored private var peripheral: CBPeripheralManager?
    @ObservationIgnored private var token: String?
    @ObservationIgnored private var wantsScan = false
    @ObservationIgnored private var wantsAdvertise = false
    @ObservationIgnored private var readings: [String: Reading] = [:]
    @ObservationIgnored private var reporter: Task<Void, Never>?
    @ObservationIgnored private var report: (([Sighting]) -> Void)?

    func configure(token: String, advertise: Bool, scan: Bool, report: @escaping ([Sighting]) -> Void) {
        self.token = token
        self.report = report
        wantsAdvertise = advertise
        wantsScan = scan
        peripheral?.stopAdvertising()
        if advertise, peripheral == nil {
            peripheral = CBPeripheralManager(delegate: self, queue: .main)
        }
        if scan, central == nil {
            central = CBCentralManager(delegate: self, queue: .main)
        }
        apply()
        if scan, reporter == nil {
            startReporting()
        }
        if !scan {
            stopReporting()
        }
    }

    func stop() {
        wantsScan = false
        wantsAdvertise = false
        apply()
        stopReporting()
        readings = [:]
    }

    private func apply() {
        if let peripheral, peripheral.state == .poweredOn {
            if wantsAdvertise, let token, !peripheral.isAdvertising {
                peripheral.startAdvertising([
                    CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID],
                    CBAdvertisementDataLocalNameKey: token
                ])
            } else if !wantsAdvertise {
                peripheral.stopAdvertising()
            }
        }
        if let central, central.state == .poweredOn {
            if wantsScan, !central.isScanning {
                central.scanForPeripherals(withServices: [Self.serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
            } else if !wantsScan {
                central.stopScan()
            }
        }
    }

    private func startReporting() {
        reporter = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.flush()
            }
        }
    }

    private func stopReporting() {
        reporter?.cancel()
        reporter = nil
    }

    private func flush() {
        let now = Date()
        readings = readings.filter { now.timeIntervalSince($0.value.lastSeen) < 4 }
        let sightings = readings.map { Sighting(token: $0.key, rssi: Int($0.value.rssi.rounded())) }
        if !sightings.isEmpty {
            report?(sightings)
        }
    }

    fileprivate func discovered(token: String, rssi: Int) {
        let now = Date()
        if var reading = readings[token] {
            reading.rssi = reading.rssi * 0.6 + Double(rssi) * 0.4
            reading.lastSeen = now
            readings[token] = reading
        } else {
            readings[token] = Reading(rssi: Double(rssi), lastSeen: now)
        }
    }

    fileprivate func stateChanged(central state: CBManagerState) {
        bluetoothState = state
        apply()
    }

    fileprivate func stateChanged(peripheral state: CBManagerState) {
        if central == nil {
            bluetoothState = state
        }
        apply()
    }
}

extension ProximityService: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state
        MainActor.assumeIsolated { stateChanged(central: state) }
    }

    nonisolated func centralManager(
        _: CBCentralManager,
        didDiscover _: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String, RSSI.intValue < 0 else { return }
        let value = RSSI.intValue
        MainActor.assumeIsolated { discovered(token: name, rssi: value) }
    }
}

extension ProximityService: CBPeripheralManagerDelegate {
    nonisolated func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        let state = peripheral.state
        MainActor.assumeIsolated { stateChanged(peripheral: state) }
    }
}

extension CBManagerState {
    var isUsable: Bool {
        self == .poweredOn || self == .unknown || self == .resetting
    }
}
