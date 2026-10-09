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
            .task(id: store.isMockMode) { await store.loadInbox() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await store.loadInbox(force: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(store.isLoading)
                    .accessibilityIdentifier("inbox.refresh")
                    .accessibilityLabel(Text("Actualiser"))
                }
            }
        }
    }
}

private struct MockModeBanner: View {
    @EnvironmentObject var store: EmailStore

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "wand.and.stars")
            VStack(alignment: .leading, spacing: 2) {
                Text("Mode démo — ces mails sont fictifs.")
                #if DEBUG
                if !Config.isGmailConfigured {
                    Text("Dev : renseigne ton Client ID dans Config.swift pour utiliser Gmail.")
                        .font(.caption2)
                }
                #endif
            }
            .font(.caption)
            Spacer(minLength: 4)
            if Config.isGmailConfigured {
                Button("Quitter") { store.exitMockPreview() }
                    .font(.caption.bold())
            }
        }
        .foregroundStyle(.orange)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.12))
        .accessibilityElement(children: .combine)
    }
}
