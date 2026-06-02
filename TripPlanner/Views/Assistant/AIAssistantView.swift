import SwiftUI

// MARK: - AIAssistantView

struct AIAssistantView: View {

    @StateObject private var vm = AIAssistantViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    if vm.messages.isEmpty {
                        emptyState
                    } else {
                        chatList
                    }
                    if let error = vm.errorMessage {
                        errorBanner(error)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .topLeading)
            }
            .navigationTitle("Ассистент")
            .navigationBarTitleDisplayMode(.large)
            .appNavBar()
            .toolbar { toolbarContent }
            // Закрытие клавиатуры по тапу на контент чата
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                to: nil, from: nil, for: nil)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            inputBar
        }
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(role: .destructive) {
                vm.clearChat()
            } label: {
                NavBarIconButton(icon: "trash")
            }
            .disabled(vm.messages.isEmpty)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                Spacer(minLength: Spacing.xl)

                // Аватар ассистента
                ZStack {
                    Circle()
                        .fill(Color.primaryAccent.opacity(0.12))
                        .frame(width: 88, height: 88)
                    Image(systemName: "hare.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.primaryAccent)
                }

                VStack(spacing: Spacing.sm) {
                    Text("Привет! Я туристический\nассистент")
                        .font(AppFont.cardTitle)
                        .multilineTextAlignment(.center)
                    Text("Спроси о маршруте, климате, визах,\nбюджете или местных особенностях")
                        .font(AppFont.subheadline)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // Suggestion chips
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Попробуй спросить:")
                        .font(AppFont.subheadline)
                        .foregroundColor(.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    SuggestionFlowView(suggestions: vm.suggestions) { suggestion in
                        Task { await vm.sendSuggestion(suggestion) }
                    }
                }
                .padding(.horizontal, Spacing.md)

                Spacer(minLength: Spacing.xxxl)
            }
            .padding(.bottom, Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Chat List

    private var chatList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Spacing.sm, pinnedViews: []) {
                    ForEach(vm.messages, id: \.id) { message in
                        MessageBubble(message: message)
                    }

                    if vm.isLoading {
                        TypingIndicator()
                            .id("typing_indicator")
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.md)
                .padding(.bottom, 200)
            }
            .scrollDismissesKeyboard(.interactively)
            .frame(maxHeight: .infinity)
            .onChange(of: vm.messages.count) { _ in
                withAnimation(AppAnimation.quick) {
                    proxy.scrollTo(vm.messages.last?.id, anchor: .bottom)
                }
            }
            .onChange(of: vm.isLoading) { loading in
                if loading {
                    withAnimation(AppAnimation.quick) {
                        proxy.scrollTo("typing_indicator", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Error Banner

    @ViewBuilder
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.redAccent)
                .font(.system(size: 14))

            Text(message)
                .font(AppFont.subheadline)
                .foregroundColor(.redAccent)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                withAnimation(AppAnimation.quick) {
                    vm.errorMessage = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(Color.redAccent.opacity(0.08))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            TextField("Спроси о поездке...", text: $vm.inputText, axis: .vertical)
                .font(AppFont.body)
                .lineLimit(1...4)
                .tint(.primaryAccent)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 10)
                .background(Color.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                .submitLabel(.send)
                .onSubmit {
                    Task { await vm.send() }
                }

            SendArrowButton(
                size: 40,
                isDisabled: vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty || vm.isLoading
            ) {
                Task { await vm.send() }
            }
            .animation(AppAnimation.quick, value: vm.inputText.isEmpty)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.md)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: -2)
                .ignoresSafeArea(.keyboard)
        )
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {

            if isUser { Spacer(minLength: 56) }

            // Аватар ассистента
            if !isUser {
                assistantAvatar
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: Spacing.xxs) {
                Text(message.text)
                    .font(AppFont.body)
                    .foregroundColor(isUser ? .white : .textPrimary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(isUser ? Color.primaryAccent : Color(.secondarySystemBackground))
                    .clipShape(
                        RoundedRectangle(cornerRadius: Radius.lg)
                    )
                    .appShadow(.card)

                Text(message.timestamp, style: .time)
                    .font(AppFont.tiny)
                    .foregroundColor(.textSecondary)
                    .padding(.horizontal, Spacing.xs)
            }

            if !isUser { Spacer(minLength: 56) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var assistantAvatar: some View {
        ZStack {
            Circle()
                .fill(Color.primaryAccent.opacity(0.15))
                .frame(width: 32, height: 32)
            Image(systemName: "hare.fill")
                .font(.system(size: 15))
                .foregroundColor(.primaryAccent)
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animate = false

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            // Аватар
            ZStack {
                Circle()
                    .fill(Color.primaryAccent.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: "hare.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.primaryAccent)
            }

            // Три точки
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.textSecondary.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .scaleEffect(animate ? 1.3 : 0.7)
                        .animation(
                            .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.18),
                            value: animate
                        )
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .appShadow(.card)

            Spacer(minLength: 56)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { animate = true }
    }
}

// MARK: - Suggestion Chip

struct SuggestionChip: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(AppFont.subheadline)
                .foregroundColor(.primaryAccent)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Color.primaryAccent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.pill)
                        .strokeBorder(Color.primaryAccent.opacity(0.25), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Suggestion Flow View

struct SuggestionFlowView: View {
    let suggestions: [String]
    let onSelect: (String) -> Void

    var body: some View {
        FlowLayoutView(items: suggestions) { suggestion in
            SuggestionChip(text: suggestion) { onSelect(suggestion) }
        }
    }
}

// MARK: - Flow Layout View 

struct FlowLayoutView<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    @State private var totalHeight: CGFloat = .zero

    init(items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            generateContent(in: geometry)
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        var rowHeight = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(items, id: \.self) { item in
                content(item)
                    .padding(.trailing, Spacing.sm)
                    .padding(.bottom, Spacing.sm)
                    .alignmentGuide(.leading) { dim in
                        if abs(width - dim.width) > geometry.size.width {
                            width = 0
                            height -= rowHeight
                            rowHeight = 0
                        }
                        let result = width
                        if item == items.last {
                            width = 0
                        } else {
                            width -= dim.width
                        }
                        rowHeight = max(rowHeight, dim.height)
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if item == items.last {
                            height = 0
                        }
                        return result
                    }
            }
        }
        .background(viewHeightReader($totalHeight))
    }

    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        GeometryReader { geo in
            Color.clear
                .preference(key: HeightPreferenceKey.self, value: geo.size.height)
        }
        .onPreferenceChange(HeightPreferenceKey.self) { binding.wrappedValue = $0 }
    }
}

private struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Preview

#Preview {
    AIAssistantView()
}
