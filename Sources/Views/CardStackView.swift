import SwiftUI

struct CardStackView: View {
    @EnvironmentObject var store: EmailStore

    @State private var pendingReply: EmailCard?
    @State private var pendingSnooze: EmailCard?
    @State private var noReplyCard: EmailCard?
    @State private var resetTokens: [String: Int] = [:]

    private let maxVisible = 3

    var body: some View {
        ZStack {
            if store.inbox.isEmpty && (store.isLoading || store.isLoadingMore) {
                ProgressView()
            } else if store.inbox.isEmpty && !store.hasMore {
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
        .onChange(of: store.inbox.count) {
            Task { await store.loadMoreIfNeeded() }
        }
        .sheet(item: $pendingReply) { card in
            ReplySheet(card: card) { text in
                store.reply(card, text: text)
                pendingReply = nil
            } onCancel: {
                resetTokens[card.id, default: 0] += 1
                pendingReply = nil
            }
        }
        .alert(
            "Impossible de répondre",
            isPresented: Binding(get: { noReplyCard != nil }, set: { if !$0 { noReplyCard = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(noReplyCard?.senderName ?? "Cet expéditeur") utilise une adresse « ne pas répondre ».")
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
            if let action = store.pending {
                UndoToast(action: action) { store.undo() }
                    .id(action.id)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.pending?.id)
    }

    private var visibleCards: [EmailCard] {
        Array(store.inbox.prefix(maxVisible))
    }

    private func handleCommit(card: EmailCard, direction: SwipeDirection) {
        switch direction {
        case .right:
            if ReplyBuilder.canReply(card) {
                pendingReply = card
            } else {
                resetTokens[card.id, default: 0] += 1
                noReplyCard = card
            }
        case .left:
            store.delete(card)
        case .up:
            store.archive(card)
        case .down:
            pendingSnooze = card
        }
    }
}

private struct UndoToast: View {
    let action: PendingAction
    let onUndo: () -> Void
    @State private var remaining: CGFloat = 1

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: action.direction.symbolName)
            Text(message)
                .lineLimit(1)
            Spacer(minLength: 8)
            Button("Annuler", action: onUndo)
                .bold()
                .foregroundStyle(.yellow)
        }
        .font(.subheadline)
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(alignment: .bottomLeading) {
            GeometryReader { proxy in
                Rectangle()
                    .fill(.white.opacity(0.18))
                    .frame(width: proxy.size.width * remaining)
            }
        }
        .background(Color.black.opacity(0.88))
        .clipShape(Capsule())
        .padding(.horizontal, 24)
        .onAppear {
            withAnimation(.linear(duration: action.delay)) { remaining = 0 }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var message: String {
        let name = action.card.senderName
        switch action.kind {
        case .reply: return "Réponse à \(name) en cours d'envoi"
        case .delete: return "Supprimé · \(name)"
        case .archive: return "Archivé · \(name)"
        case .snooze: return "Snoozé · \(name)"
        }
    }
}
