import SwiftUI
import PhotosUI

struct AddMemorySheet: View {

    let lat: Double
    let lng: Double
    let isNote: Bool
    let onSave: (String, [UIImage]) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var caption: String = ""
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var showPhotoPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {

                    if !isNote {
                        photoSection
                    }
                    captionSection

                    Spacer(minLength: 40)
                }
                .padding(.top, Spacing.md)
            }
            .navigationTitle(isNote ? "Добавить заметку" : "Новое воспоминание")
            .navigationBarTitleDisplayMode(.inline)
            .appNavBar()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        NavBarIconButton(icon: "xmark")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Сохранить") {
                        onSave(caption, selectedImages)
                        dismiss()
                    }
                    .buttonStyle(NavBarTextButtonStyle(color: canSave ? .primaryAccent : .textSecondary))
                    .disabled(!canSave)
                }
            }
            .onChange(of: pickerItems) { items in
                Task {
                    var images: [UIImage] = []
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let img = UIImage(data: data) {
                            images.append(img.resizedToMaxDimension(1200))
                        }
                    }
                    selectedImages = images
                }
            }
            .photosPicker(isPresented: $showPhotoPicker,
                          selection: $pickerItems,
                          maxSelectionCount: 8,
                          matching: .images)
        }
    }

    private var canSave: Bool {
        !caption.trimmingCharacters(in: .whitespaces).isEmpty || !selectedImages.isEmpty
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if selectedImages.isEmpty {
                Button {
                    PermissionManager.shared.requestIfNeeded(.photos) {
                        showPhotoPicker = true
                    }
                } label: {
                    RoundedRectangle(cornerRadius: Radius.xl)
                        .fill(Color.primaryAccent.opacity(0.07))
                        .frame(height: 180)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 38))
                                    .foregroundColor(.primaryAccent)
                                Text("Добавить фото")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primaryAccent)
                            }
                        )
                }
                .padding(.horizontal, Spacing.md)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(selectedImages.indices, id: \.self) { i in
                            Image(uiImage: selectedImages[i])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 130, height: 130)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                        }
                        Button {
                            PermissionManager.shared.requestIfNeeded(.photos) {
                                showPhotoPicker = true
                            }
                        } label: {
                            RoundedRectangle(cornerRadius: Radius.lg)
                                .fill(Color.primaryAccent.opacity(0.08))
                                .frame(width: 60, height: 130)
                                .overlay(
                                    Image(systemName: "plus")
                                        .foregroundColor(.primaryAccent)
                                )
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                }
                .frame(height: 130)
            }
        }
    }

    // MARK: - Caption Section

    private var captionSection: some View {
        TextField(
            isNote ? "Напиши заметку..." : "Подпись к воспоминанию...",
            text: $caption,
            axis: .vertical
        )
        .font(.system(size: 16))
        .foregroundColor(.textPrimary)
        .lineLimit(3...8)
        .padding(Spacing.md)
        .background(Color.primaryAccent.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
        .padding(.horizontal, Spacing.md)
    }
}
