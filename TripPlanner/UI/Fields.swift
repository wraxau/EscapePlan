import SwiftUI

// MARK: - Underline Text Field


struct UnderlineTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .font(AppFont.body)
                        .foregroundColor(.textPrimary)
                } else {
                    TextField("", text: $text, prompt: Text(placeholder)
                                .foregroundColor(Color(.systemGray3)))
                        .font(AppFont.body)
                        .foregroundColor(.textPrimary)
                        .textInputAutocapitalization(.never)
                        .keyboardType(
                            placeholder.lowercased().contains("почта") ? .emailAddress : .default
                        )
                }

                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.neutralGray)
                            .font(.system(size: 16))
                    }
                }
            }

            Rectangle()
                .frame(height: 1)
                .foregroundColor(text.isEmpty ? .separator : .primaryAccent)
                .animation(AppAnimation.quick, value: text.isEmpty)
        }
        .tint(.primaryAccent)
    }
}

// MARK: - App Text Field

struct AppTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var isEditing: Bool = false
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: Spacing.sm) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(.primaryAccent)
                    .frame(width: 22)
            }
            TextField("", text: $text, prompt: Text(placeholder)
                        .foregroundColor(Color(.systemGray3)))
                .font(AppFont.body)
                .foregroundColor(.textPrimary)
                .keyboardType(keyboardType)
        }
        .tint(.primaryAccent)
        .padding(Spacing.md)
        .background(Color.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .strokeBorder(Color.primaryAccent, lineWidth: isEditing ? 1.5 : 0)
                .animation(AppAnimation.quick, value: isEditing)
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: Spacing.xl) {
        VStack(spacing: Spacing.lg) {
            Text("UnderlineTextField").font(AppFont.caption).foregroundColor(.textSecondary)
            UnderlineTextField(placeholder: "Почта", text: .constant(""))
            UnderlineTextField(placeholder: "Пароль", text: .constant("qwerty123"), isSecure: true)
        }

        Divider()

        VStack(spacing: Spacing.md) {
            Text("AppTextField").font(AppFont.caption).foregroundColor(.textSecondary)
            AppTextField(placeholder: "Название поездки", text: .constant(""), icon: "airplane")
            AppTextField(placeholder: "Бюджет", text: .constant("1200"), icon: "creditcard")
            AppTextField(placeholder: "Имя (в режиме редактирования)", text: .constant("Нина"), icon: "person", isEditing: true)
        }
    }
    .padding(Spacing.md)
}
