import SwiftUI

struct CardStackView: View {
    @EnvironmentObject var store: EmailStore

    @State private var pendingReply: EmailCard?
    @State private var pendingSnooze: EmailCard?
    @State private var resetTokens: [String: Int] = [:]
    @State private var showUndoToast = false

    private let maxVisible = 3

    var body: some View {
        ZStack {
            if store.inbox.isEmpty && !store.isLoading {
                EmptyStateView(
                    icon: "tray",
                    title: "Boîte vide",
                    message: "Tu as traité tous tes mails. Bravo ! ✨"
                )
            }

            ForEach(Array(visibleCards.enumerated().reversed()), id: \.element.id) { index, card in
                if index == 0 {
                    SwipeCardView(
                        content: { EmailCardContent(card: card) },
                        onCommit: { direction in handleCommit(card: card, direction: direction) }
                    )
                    .id("\(card.id)-\(resetTokens[card.id, default: 0])")
                    .zIndex(Double(maxVisible - index))
                } else {
                    EmailCardContent(card: card)
                        .scaleEffect(1 - CGFloat(index) * 0.04)
                        .offset(y: CGFloat(index) * 10)
                        .opacity(1 - Double(index) * 0.25)
                        .zIndex(Double(maxVisible - index))
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .sheet(item: $pendingReply) { card in
            ReplySheet(card: card) { text in
                store.reply(card, text: text)
                pendingReply = nil
                withAnimation { showUndoToast = true }
            } onCancel: {
                resetTokens[card.id, default: 0] += 1
                pendingReply = nil
            }
        }
        .sheet(item: $pendingSnooze) { card in
            SnoozePickerSheet { duration in
                store.snooze(card, duration: duration)
                pendingSnooze = nil
            } onCancel: {
                resetTokens[card.id, default: 0] += 1
                pendingSnooze = nil
            }
        }
        .overlay(alignment: .bottom) {
            if showUndoToast, let action = store.lastAction {
                UndoToast(action: action) { showUndoToast = false }
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        withAnimation { showUndoToast = false }
                    }
            }
        }
    }

    private var visibleCards: [EmailCard] {
        Array(store.inbox.prefix(maxVisible))
    }

    private func handleCommit(card: EmailCard, direction: SwipeDirection) {
        switch direction {
        case .right:
            pendingReply = card
        case .left:
            store.delete(card)
            withAnimation { showUndoToast = true }
        case .up:
            store.archive(card)
            withAnimation { showUndoToast = true }
        case .down:
            pendingSnooze = card
        }
    }
}

private struct UndoToast: View {
    let action: EmailStore.LastAction
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: action.direction.symbolName)
            Text("\(action.direction.actionTitle) · \(action.card.senderName)")
                .lineLimit(1)
            Spacer(minLength: 8)
        }
        .font(.subheadline)
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.85), in: Capsule())
        .padding(.horizontal, 24)
    }
}
