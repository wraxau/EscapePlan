import SwiftUI

struct SyncStatusView: View {
    let syncState: SyncState
    let onRetry: (() -> Void)?

    var body: some View {
        Group {
            switch syncState {
            case .idle:
                EmptyView()

            case .syncing:
                HStack(spacing: Spacing.sm) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Синхронизируется...")
                        .font(AppFont.caption)
                        .foregroundColor(.textSecondary)
                }
                .padding(Spacing.sm)

            case .error(let message):
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.red)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ошибка синхронизации")
                            .font(AppFont.caption)
                            .foregroundColor(.red)
                        Text(message)
                            .font(AppFont.tiny)
                            .foregroundColor(.textSecondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    if let onRetry = onRetry {
                        Button(action: onRetry) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Spacing.sm)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))

            case .success:
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)

                    Text("Синхронизировано")
                        .font(AppFont.tiny)
                        .foregroundColor(.textSecondary)

                    Spacer()
                }
                .padding(Spacing.sm)
                .opacity(0.7)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: Spacing.md) {
        SyncStatusView(syncState: .idle, onRetry: nil)

        SyncStatusView(syncState: .syncing, onRetry: nil)

        SyncStatusView(
            syncState: .error("Проблема с интернетом"),
            onRetry: { print("Retry") }
        )

        SyncStatusView(syncState: .success, onRetry: nil)

        Spacer()
    }
    .padding(Spacing.md)
}
