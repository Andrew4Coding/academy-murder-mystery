import CoreBluetooth
import Foundation
import Observation

@MainActor @Observable
final class ProximityService: NSObject {
    static var serviceUUID: CBUUID {
        CBUUID(string: "6A1C0B5E-3F6E-4C1A-9B2B-3A1F5D7C9E01")
    }

    static var tokenUUID: CBUUID {
        CBUUID(string: "6A1C0B5E-3F6E-4C1A-9B2B-3A1F5D7C9E02")
    }

    private struct Reading {
        var rssi: Double
        var lastSeen: Date
    }

    private(set) var bluetoothState: CBManagerState = .unknown

    @ObservationIgnored private var central: CBCentralManager?
    @ObservationIgnored private var peripheral: CBPeripheralManager?
    @ObservationIgnored private var token: String?
    @ObservationIgnored private var publishedToken: String?
    @ObservationIgnored private var wantsScan = false
    @ObservationIgnored private var wantsAdvertise = false
    @ObservationIgnored private var readings: [String: Reading] = [:]
    @ObservationIgnored private var reporter: Task<Void, Never>?
    @ObservationIgnored private var report: (([Sighting]) -> Void)?
    @ObservationIgnored private var links: [UUID: CBPeripheral] = [:]
    @ObservationIgnored private var linkTokens: [UUID: String] = [:]

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
        dropLinks()
        readings = [:]
    }

    private func apply() {
        if let peripheral, peripheral.state == .poweredOn {
            if wantsAdvertise, let token {
                publish(token: token, on: peripheral)
                if !peripheral.isAdvertising {
                    peripheral.startAdvertising([
                        CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID],
                        CBAdvertisementDataLocalNameKey: token
                    ])
                }
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

    private func publish(token: String, on peripheral: CBPeripheralManager) {
        guard publishedToken != token else { return }
        peripheral.removeAllServices()
        let characteristic = CBMutableCharacteristic(
            type: Self.tokenUUID,
            properties: .read,
            value: Data(token.utf8),
            permissions: .readable
        )
        let service = CBMutableService(type: Self.serviceUUID, primary: true)
        service.characteristics = [characteristic]
        peripheral.add(service)
        publishedToken = token
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
        for link in links.values where link.state == .connected {
            link.readRSSI()
        }
        readings = readings.filter { now.timeIntervalSince($0.value.lastSeen) < 4 }
        let sightings = readings.map { Sighting(token: $0.key, rssi: Int($0.value.rssi.rounded())) }
        if !sightings.isEmpty {
            report?(sightings)
        }
    }

    private func dropLinks() {
        for link in links.values {
            central?.cancelPeripheralConnection(link)
        }
        links = [:]
        linkTokens = [:]
    }

    func discovered(token: String, rssi: Int) {
        let now = Date()
        if var reading = readings[token] {
            reading.rssi = reading.rssi * 0.6 + Double(rssi) * 0.4
            reading.lastSeen = now
            readings[token] = reading
        } else {
            readings[token] = Reading(rssi: Double(rssi), lastSeen: now)
        }
    }

    func discoveredWithoutName(_ peripheral: CBPeripheral, rssi: Int) {
        if let token = linkTokens[peripheral.identifier] {
            discovered(token: token, rssi: rssi)
        } else if links[peripheral.identifier] == nil {
            links[peripheral.identifier] = peripheral
            peripheral.delegate = self
            central?.connect(peripheral)
        }
    }

    func connected(_ peripheral: CBPeripheral) {
        peripheral.discoverServices([Self.serviceUUID])
    }

    func disconnected(_ peripheral: CBPeripheral) {
        links[peripheral.identifier] = nil
        linkTokens[peripheral.identifier] = nil
    }

    func stateChanged(central state: CBManagerState) {
        bluetoothState = state
        apply()
    }

    func stateChanged(peripheral state: CBManagerState) {
        if central == nil {
            bluetoothState = state
        }
        if state != .poweredOn {
            publishedToken = nil
        }
        apply()
    }
}

extension ProximityService: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        stateChanged(central: central.state)
    }

    func centralManager(
        _: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard RSSI.intValue < 0 else { return }
        if let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            discovered(token: name, rssi: RSSI.intValue)
        } else {
            discoveredWithoutName(peripheral, rssi: RSSI.intValue)
        }
    }

    func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connected(peripheral)
    }

    func centralManager(_: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error _: Error?) {
        disconnected(peripheral)
    }

    func centralManager(_: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error _: Error?) {
        disconnected(peripheral)
    }
}

extension ProximityService: @preconcurrency CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices _: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.serviceUUID }) else { return }
        peripheral.discoverCharacteristics([Self.tokenUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error _: Error?) {
        guard let characteristic = service.characteristics?.first(where: { $0.uuid == Self.tokenUUID }) else { return }
        peripheral.readValue(for: characteristic)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error _: Error?) {
        guard characteristic.uuid == Self.tokenUUID,
              let data = characteristic.value,
              let token = String(data: data, encoding: .utf8) else { return }
        linkTokens[peripheral.identifier] = token
        peripheral.readRSSI()
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        guard error == nil, RSSI.intValue < 0, let token = linkTokens[peripheral.identifier] else { return }
        discovered(token: token, rssi: RSSI.intValue)
    }
}

extension ProximityService: @preconcurrency CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        stateChanged(peripheral: peripheral.state)
    }
}

extension CBManagerState {
    var isUsable: Bool {
        self == .poweredOn || self == .unknown || self == .resetting
    }
}

#if DEBUG
    extension ProximityService {
        convenience init(previewState: CBManagerState) {
            self.init()
            bluetoothState = previewState
        }
    }
#endif
