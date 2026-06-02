
import SwiftUI

// MARK: - Participant Avatar

struct ParticipantAvatar: View {
    let name: String
    var size: CGFloat = 40
    var isOwner: Bool = false
    var tintColor: Color? = nil

    private var accent: Color { tintColor ?? .primaryAccent }

    private var initials: String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }.map { String($0) }
        return letters.joined().uppercased()
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(isOwner ? accent : accent.opacity(0.15))
                .frame(width: size, height: size)

            Text(initials.isEmpty ? "?" : initials)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundColor(isOwner ? .buttonText : accent)
        }
        .overlay(alignment: .topTrailing) {
            if isOwner {
                Image(systemName: "crown.fill")
                    .font(.system(size: size * 0.25))
                    .foregroundColor(.orangeAccent)
                    .offset(x: size * 0.1, y: -size * 0.1)
            }
        }
    }
}

// MARK: - Avatar Stack

struct AvatarStack: View {
    let names: [String]
    var maxVisible: Int = 3
    var size: CGFloat = 32
    var overlap: CGFloat = 10

    private var visible: [String] { Array(names.prefix(maxVisible)) }
    private var extra: Int { max(0, names.count - maxVisible) }

    var body: some View {
        HStack(spacing: -(overlap)) {
            ForEach(Array(visible.enumerated()), id: \.offset) { index, name in
                ParticipantAvatar(name: name, size: size)
                    .overlay(Circle().stroke(Color.cardBackground, lineWidth: 2))
                    .zIndex(Double(visible.count - index))
            }

            if extra > 0 {
                ZStack {
                    Circle()
                        .fill(Color.neutralGray.opacity(0.2))
                        .frame(width: size, height: size)
                    Text("+\(extra)")
                        .font(.system(size: size * 0.3, weight: .semibold))
                        .foregroundColor(.textSecondary)
                }
                .overlay(Circle().stroke(Color.cardBackground, lineWidth: 2))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: Spacing.xl) {
        HStack(spacing: Spacing.md) {
            ParticipantAvatar(name: "Нина Иванова", size: 56, isOwner: true)
            ParticipantAvatar(name: "Саша Петров", size: 56)
            ParticipantAvatar(name: "М", size: 56)
        }

        AvatarStack(names: ["Нина Иванова", "Саша Петров", "Вася", "Аня", "Коля"])
        AvatarStack(names: ["Нина", "Саша"], size: 40)
    }
    .padding(Spacing.md)
}
