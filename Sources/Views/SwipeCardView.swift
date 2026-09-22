import SwiftUI

/// Carte draggable au doigt, suit le geste 1:1 pour un rendu fluide,
/// et déclenche une action selon la direction dominante du swipe.
struct SwipeCardView<Content: View>: View {
    let content: Content
    let onCommit: (SwipeDirection) -> Void

    @State private var offset: CGSize = .zero
    @State private var isDragging = false

    private let commitDistance: CGFloat = 130
    private let commitVelocity: CGFloat = 700

    init(@ViewBuilder content: () -> Content, onCommit: @escaping (SwipeDirection) -> Void) {
        self.content = content()
        self.onCommit = onCommit
    }

    var body: some View {
        content
            .overlay(alignment: .topLeading) { hintBadge }
            .rotationEffect(.degrees(Double(offset.width / 20)))
            .offset(offset)
            .scaleEffect(isDragging ? 1.03 : 1.0)
            .gesture(dragGesture)
            .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.85), value: isDragging)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                isDragging = true
                offset = value.translation
            }
            .onEnded { value in
                isDragging = false
                let translation = value.translation
                let velocity = CGSize(
                    width: value.predictedEndLocation.x - value.location.x,
                    height: value.predictedEndLocation.y - value.location.y
                )
                resolveGesture(translation: translation, velocity: velocity)
            }
    }

    private func resolveGesture(translation: CGSize, velocity: CGSize) {
        let horizontalWins = abs(translation.width) > abs(translation.height)
        let distance = horizontalWins ? abs(translation.width) : abs(translation.height)
        let vel = horizontalWins ? abs(velocity.width) : abs(velocity.height)

        guard distance > commitDistance || vel > commitVelocity else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                offset = .zero
            }
            return
        }

        let direction: SwipeDirection
        if horizontalWins {
            direction = translation.width > 0 ? .right : .left
        } else {
            direction = translation.height > 0 ? .down : .up
        }

        let flyOut = CGSize(
            width: direction == .right ? 900 : (direction == .left ? -900 : translation.width * 3),
            height: direction == .up ? -900 : (direction == .down ? 900 : translation.height * 3)
        )
        withAnimation(.easeOut(duration: 0.28)) {
            offset = flyOut
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onCommit(direction)
        }
    }

    @ViewBuilder
    private var hintBadge: some View {
        if let direction = activeDirection {
            HStack(spacing: 6) {
                Image(systemName: direction.symbolName)
                Text(direction.actionTitle.uppercased())
                    .font(.caption.bold())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color(for: direction).opacity(0.9), in: Capsule())
            .foregroundStyle(.white)
            .padding(18)
            .opacity(min(1, progress))
            .rotationEffect(.degrees(-12))
        }
    }

    private var activeDirection: SwipeDirection? {
        guard offset != .zero else { return nil }
        let horizontalWins = abs(offset.width) > abs(offset.height)
        if horizontalWins {
            return offset.width > 20 ? .right : (offset.width < -20 ? .left : nil)
        } else {
            return offset.height < -20 ? .up : (offset.height > 20 ? .down : nil)
        }
    }

    private var progress: Double {
        let distance = max(abs(offset.width), abs(offset.height))
        return Double(distance / commitDistance)
    }

    private func color(for direction: SwipeDirection) -> Color {
        switch direction {
        case .right: return .green
        case .left: return .red
        case .up: return .blue
        case .down: return .purple
        }
    }
}
