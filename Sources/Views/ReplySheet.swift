import SwiftUI

struct ReplySheet: View {
    let card: EmailCard
    let onSend: (String) -> Void
    let onCancel: () -> Void

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("À \(card.senderName)")
                        .font(.subheadline.bold())
                    Text("Re: \(card.subject)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                TextEditor(text: $text)
                    .focused($focused)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
                    .padding(.horizontal)
                    .frame(minHeight: 180)

                quickReplies

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
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .bold()
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
    }

    private var quickReplies: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(["Merci, bien reçu !", "Je regarde ça et je reviens vers toi.", "Ok pour moi 👍", "Pas dispo, on reprogramme ?"], id: \.self) { suggestion in
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
