import SwiftUI

struct ReplySheet: View {
    let card: EmailCard
    let onSend: (String) -> Void
    let onCancel: () -> Void

    @EnvironmentObject private var store: EmailStore
    @State private var text: String = ""
    @State private var original: String?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("À \(card.senderName)")
                        .font(.subheadline.bold())
                    Text(ReplyBuilder.replyAddress(for: card))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Re: \(card.subject)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                TextEditor(text: $text)
                    .accessibilityIdentifier("reply.text")
                    .focused($focused)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
                    .padding(.horizontal)
                    .frame(minHeight: 180)

                quickReplies

                DisclosureGroup("Mail d'origine") {
                    ScrollView {
                        Text(original ?? card.snippet)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 160)
                }
                .padding(.horizontal)
                .task { original = try? await store.body(for: card) }

                Spacer()
            }
            .padding(.top, 12)
            .navigationTitle("Répondre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Envoyer") { onSend(text) }
                        .accessibilityIdentifier("reply.send")
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .bold()
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
    }

    private static var suggestions: [String] {
        [
            String(localized: "Merci, bien reçu !"),
            String(localized: "Je regarde ça et je reviens vers toi."),
            String(localized: "Ok pour moi 👍"),
            String(localized: "Pas dispo, on reprogramme ?"),
        ]
    }

    private var quickReplies: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.suggestions, id: \.self) { suggestion in
                    Button(suggestion) { text = suggestion }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.tertiarySystemBackground), in: Capsule())
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal)
        }
    }
}
