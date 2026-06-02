import SwiftUI

struct OfflineIndicatorView: View {

    @StateObject private var networkMonitor = NetworkMonitor.shared

    var body: some View {
        if !networkMonitor.isConnected {
            VStack(spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Нет интернета")
                            .font(AppFont.caption)
                            .foregroundColor(.white)
                        Text("Изменения будут синхронизированы автоматически")
                            .font(AppFont.tiny)
                            .foregroundColor(.white.opacity(0.9))
                    }

                    Spacer()
                }
                .padding(Spacing.sm)
                .background(Color.red.opacity(0.9))
                .cornerRadius(Radius.sm)
            }
            .padding(Spacing.sm)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

#Preview {
    VStack {
        OfflineIndicatorView()
        Spacer()
    }
    .screenBackground()
}
