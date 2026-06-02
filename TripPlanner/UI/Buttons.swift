import SwiftUI

// MARK: - Primary Button

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .buttonText))
                        .scaleEffect(0.85)
                } else {
                    if let icon { Image(systemName: icon) }
                    Text(title)
                        .font(AppFont.display(17))
                }
            }
            .foregroundColor(.buttonText)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.primaryAccent)
            .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
        }
        .disabled(isLoading)
    }
}

// MARK: - Secondary Button

struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .buttonText))
                        .scaleEffect(0.85)
                } else {
                    if let icon { Image(systemName: icon) }
                    Text(title)
                        .font(AppFont.display(17))
                }
            }
            .foregroundColor(.buttonText)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.secondaryAccent)
            .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
        }
        .disabled(isLoading)
    }
}

// MARK: - Destructive Button

struct DestructiveButton: View {
    let title: String
    var icon: String? = "trash"
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            HStack(spacing: Spacing.sm) {
                if let icon { Image(systemName: icon) }
                Text(title).font(AppFont.display(17))
            }
            .foregroundColor(.redAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(Color.redAccent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
            .contentShape(Rectangle().size(width: .infinity, height: 44))
        }
        .frame(minHeight: 44)
        .contentShape(RoundedRectangle(cornerRadius: Radius.pill))
    }
}

// MARK: - Icon Button

struct IconButton: View {
    let icon: String
    var color: Color = .primaryAccent
    var background: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(background ? color.opacity(0.12) : Color.clear)
                .clipShape(Circle())
        }
    }
}

// MARK: - NavBar Icon Button

struct NavBarIconButton: View {
    let icon: String
    var color: Color = .textPrimary

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(color)
    }
}

// MARK: - NavBar Text Button

struct NavBarTextButtonStyle: ButtonStyle {
    var color: Color = .primaryAccent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(color)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

// MARK: - FAB Button

struct FABButton: View {
    let icon: String
    var color: Color = .primaryAccent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(color)
                .clipShape(Circle())
                .appShadow(.fab)
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(label)
                    .font(isSelected ? AppFont.caption.weight(.semibold) : AppFont.caption)
            }
            .foregroundColor(isSelected ? .buttonText : .textSecondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(isSelected ? Color.primaryAccent : Color.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
        }
        .buttonStyle(.plain)
        .animation(AppAnimation.quick, value: isSelected)
    }
}

// MARK: - Outline Button

struct OutlineButton: View {
    let title: String
    var icon: String? = nil
    var color: Color = .primaryAccent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if let icon { Image(systemName: icon).font(.system(size: 15)) }
                Text(title).font(AppFont.body.weight(.medium))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(color.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
        }
        .frame(minHeight: 44)
        .contentShape(RoundedRectangle(cornerRadius: Radius.pill))
    }
}

// MARK: - Map Action Button

struct MapActionButton: View {
    let icon: String
    let label: String
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isActive ? Color.primaryAccent : Color(.systemGray5))
                        .frame(width: 54, height: 54)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isActive ? .white : .textPrimary)
                }
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .animation(AppAnimation.quick, value: isActive)
    }
}

struct MapActionBar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 0) {
            content
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.10), radius: 16, y: -4)
        )
    }
}

// MARK: - Send/Arrow Up Button (for modals)

struct SendArrowButton: View {
    @Environment(\.colorScheme) private var colorScheme

    var size: CGFloat = 40
    var isDisabled: Bool = false
    let action: () -> Void

    private var iconColor: Color {
        colorScheme == .dark ? .white : .black
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(iconColor)
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1.0)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: Spacing.md) {
            PrimaryButton(title: "Далее") {}
                .padding(.horizontal, Spacing.buttonHorizontalPadding)
            SecondaryButton(title: "Назад") {}
                .padding(.horizontal, Spacing.buttonHorizontalPadding)
            DestructiveButton(title: "Удалить поездку") {}
                .padding(.horizontal, Spacing.buttonHorizontalPadding)
            OutlineButton(title: "Добавить друга", icon: "person.badge.plus") {}
                .padding(.horizontal, Spacing.buttonHorizontalPadding)
            HStack(spacing: Spacing.md) {
                IconButton(icon: "bell", background: true) {}
                FABButton(icon: "plus") {}
                SendArrowButton(action: {})
            }
            HStack(spacing: Spacing.sm) {
                FilterChip(label: "Все", isSelected: true) {}
                FilterChip(label: "Кафе", icon: "fork.knife", isSelected: false) {}
                FilterChip(label: "USD", isSelected: false) {}
            }
        }
        .padding(.vertical, Spacing.md)
    }
}
