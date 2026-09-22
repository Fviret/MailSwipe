import Foundation
import UserNotifications

/// Fonctionnalité innovante V1 : "Snooze intelligent".
/// Swipe vers le bas = le mail disparaît de la pile et réapparaît tout en
/// haut de l'Inbox à l'heure choisie, avec une notification locale de rappel.
@MainActor
final class SnoozeScheduler: ObservableObject {
    @Published private(set) var items: [SnoozeItem] = []

    private let storageKey = "mailswipe.snoozed"

    init() {
        load()
    }

    func snooze(_ card: EmailCard, until date: Date) {
        let item = SnoozeItem(id: card.id, card: SnoozedCardData(from: card), wakeAt: date)
        items.removeAll { $0.id == card.id }
        items.append(item)
        save()
        requestNotificationPermission()
        scheduleNotification(for: item)
    }

    func cancel(_ item: SnoozeItem) {
        items.removeAll { $0.id == item.id }
        save()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [item.id])
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
        content.title = "📬 De retour : \(item.card.senderName)"
        content.body = item.card.subject
        content.sound = .default

        let interval = max(item.wakeAt.timeIntervalSinceNow, 1)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: item.id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([SnoozeItem].self, from: data)
        else { return }
        items = decoded
    }
}
