import Foundation
import Combine

@MainActor
final class OfflineOperationQueue: ObservableObject {

    typealias Operation = () async throws -> Void

    // MARK: - Published Properties

    @Published var pendingOperationCount: Int = 0
    @Published var hasFailedOperations: Bool = false

    // MARK: - Private

    private var operations: [Operation] = []
    private var failedOperations: [Operation] = []
    private let networkMonitor = NetworkMonitor.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupNetworkObserver()
    }

    // MARK: - Public Methods

    func enqueue(_ operation: @escaping Operation) {
        operations.append(operation)
        updatePendingCount()
    }

    func processQueue() async {
        while !operations.isEmpty {
            let operation = operations.removeFirst()
            await executeOperation(operation)
        }
        updatePendingCount()
    }

    func retryFailedOperations() async {
        let failed = failedOperations
        failedOperations.removeAll()

        for operation in failed {
            operations.append(operation)
        }

        await processQueue()
        updatePendingCount()
    }

    // MARK: - Private Methods

    private func executeOperation(_ operation: @escaping Operation) async {
        do {
            try await operation()
        } catch {
            if !networkMonitor.isConnected {
                failedOperations.append(operation)
                hasFailedOperations = !failedOperations.isEmpty
            }
        }
    }

    private func updatePendingCount() {
        pendingOperationCount = operations.count + failedOperations.count
    }

    private func setupNetworkObserver() {
        networkMonitor.$isConnected
            .filter { $0 } // Только когда сеть восстановилась
            .debounce(for: 0.5, scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.retryFailedOperations()
                }
            }
            .store(in: &cancellables)
    }
}
