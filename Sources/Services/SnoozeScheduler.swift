import Foundation
import UserNotifications

/// Rappels locaux ; injectable pour que les tests n'appellent jamais le vrai centre de notifications.
protocol NotificationScheduling {
    func requestPermission()
    func schedule(id: String, title: String, body: String, at date: Date)
    func cancel(ids: [String])
}

struct SystemNotificationScheduler: NotificationScheduling {
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func schedule(id: String, title: String, body: String, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(date.timeIntervalSinceNow, 1), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func cancel(ids: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
}

/// Fonctionnalité innovante V1 : "Snooze intelligent".
/// Swipe vers le bas = le mail disparaît de la pile et réapparaît tout en
/// haut de l'Inbox à l'heure choisie, avec une notification locale de rappel.
@MainActor
final class SnoozeScheduler: ObservableObject {
    @Published private(set) var items: [SnoozeItem] = []

    private var storage: JSONFileStore<[SnoozeItem]>
    private let notifications: NotificationScheduling

    init(directory: URL? = nil, notifications: NotificationScheduling = SystemNotificationScheduler()) {
        self.notifications = notifications
        storage = JSONFileStore(filename: "snoozed.json", directory: directory)
        items = storage.load() ?? []
    }

    /// Bascule vers un autre dossier de données (démo ↔ compte réel) sans mélanger les mails.
    func use(directory: URL) {
        notifications.cancel(ids: items.map(\.id))
        storage = JSONFileStore(filename: "snoozed.json", directory: directory)
        items = storage.load() ?? []
        for item in items where item.wakeAt > Date() { scheduleNotification(for: item) }
    }

    func snooze(_ card: EmailCard, until date: Date) {
        let item = SnoozeItem(id: card.id, card: card, wakeAt: date)
        items.removeAll { $0.id == card.id }
        items.append(item)
        save()
        notifications.requestPermission()
        scheduleNotification(for: item)
    }

    func cancel(_ item: SnoozeItem) {
        remove(id: item.id)
    }

    func remove(id: String) {
        items.removeAll { $0.id == id }
        save()
        notifications.cancel(ids: [id])
    }

    /// Retourne les mails dont l'heure de réveil est passée, et les retire de la liste snoozée.
    func popDueItems(now: Date = Date()) -> [SnoozeItem] {
        let due = items.filter { $0.wakeAt <= now }
        guard !due.isEmpty else { return [] }
        items.removeAll { item in due.contains { $0.id == item.id } }
        save()
        return due
    }

    private func scheduleNotification(for item: SnoozeItem) {
        // Volontairement générique : l'expéditeur et l'objet ne doivent pas s'afficher sur l'écran verrouillé.
        notifications.schedule(
            id: item.id,
            title: String(localized: "📬 Un mail snoozé est de retour"),
            body: String(localized: "Ouvre MailSwipe pour le traiter."),
            at: item.wakeAt
        )
    }

    /// Efface tous les mails snoozés (déconnexion).
    func removeAll() {
        let ids = items.map(\.id)
        items = []
        storage.delete()
        notifications.cancel(ids: ids)
    }

    private func save() {
        storage.save(items)
    }
}
