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
                        .onTapGesture { store.errorMessage = nil }
                        .accessibilityHint("Toucher pour masquer")
                }

                if store.isLoading && store.inbox.isEmpty {
                    Spacer()
                    ProgressView("Chargement…")
                    Spacer()
                } else {
                    CardStackView()
                }
            }
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.inline)
            .task { await store.loadInbox() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await store.loadInbox(force: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(store.isLoading)
                    .accessibilityLabel(Text("Actualiser"))
                }
            }
        }
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
