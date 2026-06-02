import Foundation
import Network
import Combine

@MainActor
final class NetworkMonitor: ObservableObject {

    static let shared = NetworkMonitor()

    // MARK: - Published Properties


    @Published var isConnected: Bool = true
    @Published var connectionType: NWInterface.InterfaceType? = nil
    @Published var statusDescription: String = "Подключено"

    // MARK: - Private

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.tripplanner.network")

    private init() {
        startMonitoring()
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Monitoring
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateStatus(path: path)
            }
        }
        monitor.start(queue: queue)
    }

    // MARK: - Status Update
    private func updateStatus(path: NWPath) {
        let isConnected = path.status == .satisfied
        let connectionType = getConnectionType(path: path)

        self.isConnected = isConnected
        self.connectionType = connectionType

        if !isConnected {
            self.statusDescription = "Нет интернета"
        } else if path.usesInterfaceType(.wifi) {
            self.statusDescription = "Wi-Fi"
        } else if path.usesInterfaceType(.cellular) {
            self.statusDescription = "Мобильная сеть"
        } else if path.usesInterfaceType(.wiredEthernet) {
            self.statusDescription = "Проводное подключение"
        } else {
            self.statusDescription = "Подключено"
        }
    }

    /// Определяет тип текущего соединения
    private func getConnectionType(path: NWPath) -> NWInterface.InterfaceType? {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wiredEthernet
        }
        return nil
    }

    // MARK: - Helpers

    func hasConnection() -> Bool {
        isConnected
    }
    func isOnWiFi() -> Bool {
        connectionType == .wifi
    }
    func isOnCellular() -> Bool {
        connectionType == .cellular
    }
}
