import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var store: EmailStore

    var body: some View {
        TabView {
            InboxView()
                .tabItem { Label("Inbox", systemImage: "tray.fill") }

            ArchiveListView()
                .tabItem { Label("Archive", systemImage: "archivebox.fill") }

            SnoozedListView()
                .tabItem { Label("Snoozés", systemImage: "clock.fill") }
                .badge(store.snoozeScheduler.items.isEmpty ? 0 : store.snoozeScheduler.items.count)

            SettingsView()
                .tabItem { Label("Réglages", systemImage: "gearshape.fill") }
        }
    }
}
