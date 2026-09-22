import SwiftUI

/// L'archive reprend exactement les mêmes informations que la carte :
/// titre, résumé et provenance du mail.
struct ArchiveListView: View {
    @EnvironmentObject var store: EmailStore

    var body: some View {
        NavigationStack {
            Group {
                if store.archived.isEmpty {
                    EmptyStateView(
                        icon: "archivebox",
                        title: "Aucun mail archivé",
                        message: "Les mails que tu archives (swipe vers le haut) apparaîtront ici."
                    )
                } else {
                    List(store.archived) { card in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(card.senderName)
                                    .font(.subheadline.bold())
                                Spacer()
                                Text(card.date, style: .date)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(card.subject)
                                .font(.body.weight(.semibold))
                            Text(card.snippet)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Archive")
        }
    }
}
