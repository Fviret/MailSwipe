import SwiftUI

/// Le contenu visuel d'une carte mail : provenance, titre, résumé.
/// Réutilisé à l'identique pour l'Inbox et pour l'Archive.
struct EmailCardContent: View {
    let card: EmailCard

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                senderAvatar
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.senderName)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text(card.senderEmail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    if card.isUnread {
                        Circle().fill(Color.accentColor).frame(width: 8, height: 8)
                    }
                    Text(card.date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(card.subject)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                Text(card.snippet)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(6)
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.12), radius: 18, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }

    private var senderAvatar: some View {
        Circle()
            .fill(avatarColor.gradient)
            .frame(width: 44, height: 44)
            .overlay(
                Text(initials)
                    .font(.headline)
                    .foregroundStyle(.white)
            )
    }

    private var initials: String {
        let parts = card.senderName.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    private var avatarColor: Color {
        let palette: [Color] = [.blue, .purple, .orange, .pink, .teal, .indigo]
        let index = abs(card.senderEmail.hashValue) % palette.count
        return palette[index]
    }
}
