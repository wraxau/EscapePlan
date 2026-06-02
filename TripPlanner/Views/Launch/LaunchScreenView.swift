import SwiftUI

struct LaunchScreenView: View {

    @State private var scale: CGFloat  = 0.7
    @State private var opacity: Double = 0.0
    @State private var titleOffset: CGFloat = 20

    var body: some View {
        ZStack {
            Color.secondaryAccent
                .ignoresSafeArea()

            VStack(spacing: Spacing.md) {
                // Иконка
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundColor(.primaryAccent)
                    .scaleEffect(scale)
                    .opacity(opacity)

                // Название
                Text("TripRoute")
                    .font(AppFont.display(34))
                    .foregroundColor(.primaryAccent)
                    .offset(y: titleOffset)
                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                scale   = 1.0
                opacity = 1.0
                titleOffset = 0
            }
        }
    }
}

#Preview {
    LaunchScreenView()
}
