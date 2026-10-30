import CoreBluetooth

@MainActor
final class BluetoothPermission: NSObject, CBCentralManagerDelegate {
    static let shared = BluetoothPermission()

    private var manager: CBCentralManager?

    func request() {
        guard manager == nil else { return }
        manager = CBCentralManager(delegate: self, queue: .main, options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {}
}
