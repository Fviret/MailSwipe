import SwiftUI

struct InboxView: View {
    @EnvironmentObject var store: EmailStore

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if store.isMockMode {
                    MockModeBanner()
                }

                if let error = store.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                if store.isLoading && store.inbox.isEmpty {
                    Spacer()
                    ProgressView("Chargement…")
                    Spacer()
                } else {
                    CardStackView()
                    swipeLegend
                }
            }
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.inline)
            .task { await store.loadInbox() }
            .refreshable { await store.loadInbox(force: true) }
        }
    }

    private var swipeLegend: some View {
        HStack(spacing: 18) {
            legendItem(symbol: "trash.fill", label: "Supprimer", color: .red)
            legendItem(symbol: "clock.fill", label: "Snoozer", color: .purple)
            legendItem(symbol: "archivebox.fill", label: "Archiver", color: .blue)
            legendItem(symbol: "arrowshape.turn.up.left.fill", label: "Répondre", color: .green)
        }
        .padding(.vertical, 10)
    }

    private func legendItem(symbol: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MockModeBanner: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "wand.and.stars")
            Text("Mode démo — mails fictifs. Configure Gmail dans Config.swift.")
                .font(.caption)
        }
        .foregroundStyle(.orange)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.12))
    }
}
