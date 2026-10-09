import SwiftUI

/// Carte draggable au doigt, suit le geste 1:1 pour un rendu fluide,
/// et déclenche une action selon la direction dominante du swipe.
struct SwipeCardView<Content: View>: View {
    let content: Content
    let onCommit: (SwipeDirection) -> Void
    var onTap: (() -> Void)?

    @State private var offset: CGSize = .zero
    @State private var isDragging = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        @ViewBuilder content: () -> Content,
        onCommit: @escaping (SwipeDirection) -> Void,
        onTap: (() -> Void)? = nil
    ) {
        self.content = content()
        self.onCommit = onCommit
        self.onTap = onTap
    }

    var body: some View {
        content
            .overlay(alignment: .topLeading) { hintBadge }
            .rotationEffect(.degrees(reduceMotion ? 0 : Double(offset.width / 20)))
            .offset(offset)
            .scaleEffect(isDragging && !reduceMotion ? 1.03 : 1.0)
            .onTapGesture { onTap?() }
            .gesture(dragGesture)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("card.top")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(Text("Touchez deux fois pour lire le mail. Balayez vers le haut ou le bas pour les actions : répondre, supprimer, archiver ou snoozer."))
            .accessibilityAction(.default) { onTap?() }
            .accessibilityAction(named: Text(SwipeDirection.right.actionTitle)) { onCommit(.right) }
            .accessibilityAction(named: Text(SwipeDirection.left.actionTitle)) { onCommit(.left) }
            .accessibilityAction(named: Text(SwipeDirection.up.actionTitle)) { onCommit(.up) }
            .accessibilityAction(named: Text(SwipeDirection.down.actionTitle)) { onCommit(.down) }
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
        guard let direction = SwipeResolver.resolve(translation: translation, velocity: velocity) else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                offset = .zero
            }
            return
        }

        withAnimation(.easeOut(duration: 0.28)) {
            offset = SwipeResolver.flyOutOffset(for: direction, translation: translation)
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
            .background(direction.color.opacity(0.9), in: Capsule())
            .foregroundStyle(.white)
            .padding(18)
            .opacity(min(1, progress))
            .rotationEffect(.degrees(-12))
        }
    }

    private var activeDirection: SwipeDirection? { SwipeResolver.activeDirection(for: offset) }

    private var progress: Double { SwipeResolver.progress(for: offset) }
}
