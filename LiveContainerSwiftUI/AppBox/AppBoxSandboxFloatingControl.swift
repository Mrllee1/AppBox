import SwiftUI

struct AppBoxSandboxFloatingControl: View {
    let language: AppBoxLanguage
    let availableSize: CGSize
    let safeAreaInsets: EdgeInsets
    let returnToSandbox: () -> Void

    private enum InteractionState: Equatable {
        case idle
        case pressed
        case expanded
    }

    private enum DockEdge: String {
        case left
        case right
        case top
        case bottom
    }

    private enum Metrics {
        static let buttonSize: CGFloat = 60
        static let menuSize: CGFloat = 96
        static let edgeInset: CGFloat = 4
        static let menuInset: CGFloat = 8
        static let dragThreshold: CGFloat = 6
        static let idleDelayNanoseconds: UInt64 = 1_500_000_000
    }

    private enum DefaultsKey {
        static let edge = "AppBoxAssistiveDockEdge"
        static let ratio = "AppBoxAssistiveDockRatio"
    }

    @State private var state: InteractionState = .idle
    @State private var buttonCenter = CGPoint.zero
    @State private var dragStartCenter = CGPoint.zero
    @State private var isDragging = false
    @State private var idleTask: Task<Void, Never>?

    private var copy: AppBoxCopy { AppBoxCopy(language: language) }
    private var isExpanded: Bool { state == .expanded }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if isExpanded {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: collapseMenu)

                menuControl
                    .frame(width: Metrics.menuSize, height: Metrics.menuSize)
                    .position(menuCenter(anchoredTo: buttonCenter))
                    .transition(
                        .scale(
                            scale: Metrics.buttonSize / Metrics.menuSize,
                            anchor: expansionAnchor
                        )
                        .combined(with: .opacity)
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(copy.text("返回沙盒", "Return to Box"))
                    .accessibilityHint(copy.text("轻点返回天涯盒子", "Tap to return to Tianya Box"))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { returnToSandbox() }
            } else {
                buttonControl
                    .frame(width: Metrics.buttonSize, height: Metrics.buttonSize)
                    .position(buttonCenter)
                    .gesture(controlGesture)
                    .transition(.opacity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(copy.text("沙盒控制", "Sandbox control"))
                    .accessibilityHint(copy.text("轻点展开，拖动可调整位置", "Tap to open or drag to reposition"))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { expandMenu() }
            }
        }
        .frame(width: availableSize.width, height: availableSize.height)
        .clipped()
        .animation(.spring(response: 0.24, dampingFraction: 0.9), value: state)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: buttonCenter)
        .onAppear(perform: restorePosition)
        .onChange(of: availableSize) { _ in restorePosition() }
        .onDisappear { idleTask?.cancel() }
    }

    private var menuControl: some View {
        Button(action: returnToSandbox) {
            VStack(spacing: 6) {
                AppBoxGlyph(icon: .locationPin)
                    .frame(width: 22, height: 22)
                Text(copy.text("返回沙盒", "Return to Box"))
                    .font(.system(size: 13, weight: .regular))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(white: 75 / 255))
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 9, y: 4)
        }
        .buttonStyle(AppBoxAssistiveMenuButtonStyle())
    }

    private var buttonControl: some View {
        ZStack {
            assistiveImage(named: "AppBoxAssistiveTouchIdle")
                .opacity(state == .idle ? 1 : 0)
            assistiveImage(named: "AppBoxAssistiveTouch")
                .opacity(state == .idle ? 0 : 1)
        }
        .scaleEffect(state == .pressed ? 0.96 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func assistiveImage(named name: String) -> some View {
        Image(name)
            .resizable()
            .interpolation(.high)
            .frame(width: Metrics.buttonSize, height: Metrics.buttonSize)
    }

    private var controlGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !isExpanded else { return }
                if state != .pressed {
                    idleTask?.cancel()
                    dragStartCenter = buttonCenter
                    state = .pressed
                }

                let distance = hypot(value.translation.width, value.translation.height)
                guard distance >= Metrics.dragThreshold else { return }
                isDragging = true
                buttonCenter = clampedButtonCenter(
                    CGPoint(
                        x: dragStartCenter.x + value.translation.width,
                        y: dragStartCenter.y + value.translation.height
                    )
                )
            }
            .onEnded { _ in
                guard !isExpanded else {
                    returnToSandbox()
                    return
                }

                if isDragging {
                    snapToNearestEdge()
                    isDragging = false
                    scheduleIdleState()
                } else {
                    expandMenu()
                }
            }
    }

    private func expandMenu() {
        idleTask?.cancel()
        state = .expanded
    }

    private func collapseMenu() {
        state = .pressed
        scheduleIdleState()
    }

    private func scheduleIdleState() {
        idleTask?.cancel()
        idleTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: Metrics.idleDelayNanoseconds)
            guard !Task.isCancelled, state == .pressed else { return }
            withAnimation(.easeOut(duration: 0.28)) {
                state = .idle
            }
        }
    }

    private func restorePosition() {
        guard availableSize.width > Metrics.buttonSize,
              availableSize.height > Metrics.buttonSize else { return }

        let defaults = UserDefaults.standard
        let edge = DockEdge(rawValue: defaults.string(forKey: DefaultsKey.edge) ?? "right") ?? .right
        let savedRatio = defaults.object(forKey: DefaultsKey.ratio) as? Double
        let ratio = CGFloat(min(1, max(0, savedRatio ?? 0.92)))
        buttonCenter = center(for: edge, ratio: ratio)
        state = .idle
    }

    private func snapToNearestEdge() {
        let bounds = buttonCenterBounds
        let distances: [(DockEdge, CGFloat)] = [
            (.left, abs(buttonCenter.x - bounds.minX)),
            (.right, abs(bounds.maxX - buttonCenter.x)),
            (.top, abs(buttonCenter.y - bounds.minY)),
            (.bottom, abs(bounds.maxY - buttonCenter.y))
        ]
        let edge = distances.min(by: { $0.1 < $1.1 })?.0 ?? .right
        let ratio: CGFloat

        switch edge {
        case .left, .right:
            ratio = normalized(buttonCenter.y, min: bounds.minY, max: bounds.maxY)
        case .top, .bottom:
            ratio = normalized(buttonCenter.x, min: bounds.minX, max: bounds.maxX)
        }

        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            buttonCenter = center(for: edge, ratio: ratio)
        }
        UserDefaults.standard.set(edge.rawValue, forKey: DefaultsKey.edge)
        UserDefaults.standard.set(Double(ratio), forKey: DefaultsKey.ratio)
    }

    private var buttonCenterBounds: CGRect {
        let half = Metrics.buttonSize / 2
        return CGRect(
            x: safeAreaInsets.leading + Metrics.edgeInset + half,
            y: safeAreaInsets.top + Metrics.edgeInset + half,
            width: max(
                0,
                availableSize.width
                    - safeAreaInsets.leading
                    - safeAreaInsets.trailing
                    - (Metrics.edgeInset + half) * 2
            ),
            height: max(
                0,
                availableSize.height
                    - safeAreaInsets.top
                    - safeAreaInsets.bottom
                    - (Metrics.edgeInset + half) * 2
            )
        )
    }

    private func center(for edge: DockEdge, ratio: CGFloat) -> CGPoint {
        let bounds = buttonCenterBounds
        switch edge {
        case .left:
            return CGPoint(x: bounds.minX, y: bounds.minY + bounds.height * ratio)
        case .right:
            return CGPoint(x: bounds.maxX, y: bounds.minY + bounds.height * ratio)
        case .top:
            return CGPoint(x: bounds.minX + bounds.width * ratio, y: bounds.minY)
        case .bottom:
            return CGPoint(x: bounds.minX + bounds.width * ratio, y: bounds.maxY)
        }
    }

    private func clampedButtonCenter(_ proposed: CGPoint) -> CGPoint {
        let bounds = buttonCenterBounds
        return CGPoint(
            x: min(bounds.maxX, max(bounds.minX, proposed.x)),
            y: min(bounds.maxY, max(bounds.minY, proposed.y))
        )
    }

    private func menuCenter(anchoredTo center: CGPoint) -> CGPoint {
        let half = Metrics.menuSize / 2
        return CGPoint(
            x: min(
                availableSize.width - safeAreaInsets.trailing - Metrics.menuInset - half,
                max(safeAreaInsets.leading + Metrics.menuInset + half, center.x)
            ),
            y: min(
                availableSize.height - safeAreaInsets.bottom - Metrics.menuInset - half,
                max(safeAreaInsets.top + Metrics.menuInset + half, center.y)
            )
        )
    }

    private var expansionAnchor: UnitPoint {
        let center = menuCenter(anchoredTo: buttonCenter)
        let origin = CGPoint(
            x: center.x - Metrics.menuSize / 2,
            y: center.y - Metrics.menuSize / 2
        )
        return UnitPoint(
            x: min(1, max(0, (buttonCenter.x - origin.x) / Metrics.menuSize)),
            y: min(1, max(0, (buttonCenter.y - origin.y) / Metrics.menuSize))
        )
    }

    private func normalized(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        guard max > min else { return 0.5 }
        return Swift.min(1, Swift.max(0, (value - min) / (max - min)))
    }
}

private struct AppBoxAssistiveMenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
