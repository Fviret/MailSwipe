import SwiftUI

struct SnoozedListView: View {
    @EnvironmentObject var store: EmailStore

    var body: some View {
        NavigationStack {
            Group {
                if store.snoozeScheduler.items.isEmpty {
                    EmptyStateView(
                        icon: "clock",
                        title: "Rien en pause",
                        message: "Swipe un mail vers le bas pour le snoozer : il reviendra tout en haut de ta boîte au moment choisi."
                    )
                } else {
                    List(store.snoozeScheduler.items.sorted(by: { $0.wakeAt < $1.wakeAt })) { item in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.card.senderName)
                                    .font(.subheadline.bold())
                                Text(item.card.subject)
                                    .font(.body)
                                Text("Retour \(item.wakeAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.purple)
                            }
                            Spacer()
                            Button {
                                store.snoozeScheduler.cancel(item)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Snoozés")
        }
    }
}
