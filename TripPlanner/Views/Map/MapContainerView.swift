import SwiftUI

struct MapContainerView: View {

    @StateObject private var vm = MapViewModel()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                MapWebView(viewModel: vm)
                    .ignoresSafeArea(edges: .bottom)
                if vm.mapMode != .view {
                    VStack {
                        Text(vm.mapMode.hint)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                            .background(Color.primaryAccent)
                            .clipShape(Capsule())
                            .padding(.top, 8)
                            .shadow(color: .primaryAccent.opacity(0.4), radius: 8, y: 3)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

            }
            .animation(AppAnimation.quick, value: vm.mapMode)
            .navigationTitle("Карта")
            .navigationBarTitleDisplayMode(.inline)
            .appNavBar()
            .toolbar {
                if vm.mapMode != .view {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            withAnimation(AppAnimation.quick) { vm.mapMode = .view }
                        } label: {
                            NavBarIconButton(icon: "xmark")
                        }
                    }
                }
            }
            .sheet(isPresented: $vm.showAddMemory) {
                if let loc = vm.pendingLocation {
                    AddMemorySheet(lat: loc.0, lng: loc.1, isNote: false) { caption, images in
                        vm.addMemory(lat: loc.0, lng: loc.1, caption: caption, images: images)
                    }
                    .presentationDetents([.medium, .large])
                }
            }
            .sheet(isPresented: $vm.showAddNote) {
                if let loc = vm.pendingLocation {
                    AddMemorySheet(lat: loc.0, lng: loc.1, isNote: true) { caption, _ in
                        vm.addMemory(lat: loc.0, lng: loc.1, caption: caption, images: [], isNote: true)
                    }
                    .presentationDetents([.medium])
                }
            }
            .sheet(item: $vm.selectedMemory) { memory in
                MemoryCardView(memory: memory) {
                    vm.selectedMemory = nil
                } onDelete: {
                    vm.deleteMemory(memory)
                }
                .presentationDetents([.large])
                .presentationCornerRadius(20)
                .presentationDragIndicator(.visible)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            mapToolbar
                    .background(Color(.systemBackground)) // Фон панели
                    .padding(.bottom, -10) //
                    .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Bottom Toolbar

    private var mapToolbar: some View {
        MapActionBar {
            MapActionButton(
                icon: "camera.fill",
                label: "Добавить\nвоспоминание",
                isActive: vm.mapMode == .addPin
            ) {
                withAnimation(AppAnimation.quick) {
                    vm.mapMode = vm.mapMode == .addPin ? .view : .addPin
                }
            }

            MapActionButton(
                icon: "paintbrush.pointed.fill",
                label: "Закрасить\nстрану",
                isActive: vm.mapMode == .colorCountry
            ) {
                withAnimation(AppAnimation.quick) {
                    vm.mapMode = vm.mapMode == .colorCountry ? .view : .colorCountry
                }
            }

            MapActionButton(
                icon: "pencil",
                label: "Добавить\nзаметку",
                isActive: vm.mapMode == .addNote
            ) {
                withAnimation(AppAnimation.quick) {
                    vm.mapMode = vm.mapMode == .addNote ? .view : .addNote
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MapContainerView()
}
