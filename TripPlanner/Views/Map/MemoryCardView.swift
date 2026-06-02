import SwiftUI

struct MemoryCardView: View {

    let memory: MapMemory
    let onClose: () -> Void
    let onDelete: () -> Void

    @State private var photos: [UIImage] = []
    @State private var currentIndex: Int = 0

    var body: some View {
        VStack(spacing: 0) {

            if !photos.isEmpty {
                photoCarousel
            } else if memory.isNote {
                noteHeader
            } else {
                Color.primaryAccent.opacity(0.08)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundColor(.primaryAccent.opacity(0.3))
                    )
            }
            bottomPanel
        }
        .onAppear { loadPhotos() }
    }

    // MARK: - Photo Carousel

    private var photoCarousel: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentIndex) {
                ForEach(photos.indices, id: \.self) { i in
                    Image(uiImage: photos[i])
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .always : .never))

            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.45))
                        .clipShape(Circle())
                }
                .padding(12)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    // MARK: - Note Header (no photo)

    private var noteHeader: some View {
        HStack {
            Image(systemName: "note.text")
                .font(.system(size: 28))
                .foregroundColor(.blue.opacity(0.7))
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textSecondary)
                    .padding(8)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
        }
        .padding(Spacing.md)
        .background(Color.blue.opacity(0.06))
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: Radius.xxl,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: Radius.xxl,
                style: .continuous
            )
        )
    }

    // MARK: - Bottom Panel

    private var bottomPanel: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if !memory.caption.isEmpty {
                Text(memory.caption)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primaryAccent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(3)
            }

            HStack(spacing: 6) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                Text(String(format: "%.3f°,  %.3f°", memory.latitude, memory.longitude))
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)

                Spacer()

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.red.opacity(0.65))
                        .padding(8)
                        .background(Color.red.opacity(0.08))
                        .clipShape(Circle())
                }
            }
        }
        .padding(Spacing.md)
        .background(Color(.systemBackground))
    }

    // MARK: - Load Photos

    private func loadPhotos() {
        photos = memory.photoURLs.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }
    }
}
