import Foundation
import UserNotifications

/// Fonctionnalité innovante V1 : "Snooze intelligent".
/// Swipe vers le bas = le mail disparaît de la pile et réapparaît tout en
/// haut de l'Inbox à l'heure choisie, avec une notification locale de rappel.
@MainActor
final class SnoozeScheduler: ObservableObject {
    @Published private(set) var items: [SnoozeItem] = []

    private let storage: JSONFileStore<[SnoozeItem]>

    init(directory: URL? = nil) {
        storage = JSONFileStore(filename: "snoozed.json", directory: directory)
        items = storage.load() ?? []
    }

    func snooze(_ card: EmailCard, until date: Date) {
        let item = SnoozeItem(id: card.id, card: card, wakeAt: date)
        items.removeAll { $0.id == card.id }
        items.append(item)
        save()
        requestNotificationPermission()
        scheduleNotification(for: item)
    }

    func cancel(_ item: SnoozeItem) {
        remove(id: item.id)
    }

    func remove(id: String) {
        items.removeAll { $0.id == id }
        save()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    /// Retourne les mails dont l'heure de réveil est passée, et les retire de la liste snoozée.
    func popDueItems(now: Date = Date()) -> [SnoozeItem] {
        let due = items.filter { $0.wakeAt <= now }
        guard !due.isEmpty else { return [] }
        items.removeAll { item in due.contains { $0.id == item.id } }
        save()
        return due
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func scheduleNotification(for item: SnoozeItem) {
        let content = UNMutableNotificationContent()
        // Volontairement générique : l'expéditeur et l'objet ne doivent pas s'afficher sur l'écran verrouillé.
        content.title = "📬 Un mail snoozé est de retour"
        content.body = "Ouvre MailSwipe pour le traiter." 
        content.sound = .default

        let interval = max(item.wakeAt.timeIntervalSinceNow, 1)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: item.id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    /// Efface tous les mails snoozés (déconnexion).
    func removeAll() {
        let ids = items.map(\.id)
        items = []
        storage.delete()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func save() {
        storage.save(items)
    }
}
