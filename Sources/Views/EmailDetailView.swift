import SwiftUI

/// Lecture complète d'un mail avant de décider quoi en faire.
struct EmailDetailView: View {
    @EnvironmentObject private var store: EmailStore
    @Environment(\.dismiss) private var dismiss

    let card: EmailCard
    let onReply: () -> Void

    private enum Phase { case loading, loaded(String), failed(String) }
    @State private var phase = Phase.loading

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.subject).font(.title3.bold())
                        Text("\(card.senderName) · \(card.senderEmail)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(card.date.formatted(date: .long, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Divider()
                    content
                }
                .padding()
            }
            .navigationTitle("Mail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Répondre", action: onReply)
                        .bold()
                        .disabled(!ReplyBuilder.canReply(card))
                }
            }
            .task { await load() }
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                Text("Chargement du mail…").foregroundStyle(.secondary)
            }
        case .loaded(let text):
            Text(text.isEmpty ? card.snippet : text)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Text(card.snippet)
                Text(message).font(.caption).foregroundStyle(.red)
                Button("Réessayer") { Task { await load() } }
            }
        }
    }

    private func load() async {
        phase = .loading
        do {
            phase = .loaded(try await store.body(for: card))
        } catch {
            phase = .failed("Impossible de charger le mail complet : \(error.localizedDescription)")
        }
    }
}
