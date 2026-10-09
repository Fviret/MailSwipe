import Foundation
@testable import MailSwipe

/// Service de test : peut échouer sur demande et enregistre les appels.
final class SpyMailService: MailService, @unchecked Sendable {
    struct Failure: LocalizedError { var errorDescription: String? { "boom" } }

    var failing = false
    var cards: [EmailCard] = MockData.inbox()
    var pageSize = Int.max
    private(set) var calls: [String] = []

    private func record(_ name: String) throws {
        calls.append(name)
        if failing { throw Failure() }
    }

    func fetchInbox(pageToken: String?) async throws -> MailPage {
        try record("fetchInbox:\(pageToken ?? "-")")
        let start = Int(pageToken ?? "") ?? 0
        let end = min(start + pageSize, cards.count)
        return MailPage(cards: Array(cards[start..<end]), nextPageToken: end < cards.count ? String(end) : nil)
    }
    var bodies: [String: String] = [:]
    func fetchBody(messageId: String) async throws -> String {
        try record("body:\(messageId)")
        return bodies[messageId] ?? "corps de \(messageId)"
    }
    func trash(messageId: String) async throws { try record("trash:\(messageId)") }
    func archive(messageId: String) async throws { try record("archive:\(messageId)") }
    func snooze(messageId: String) async throws { try record("snooze:\(messageId)") }
    func unsnooze(messageId: String) async throws { try record("unsnooze:\(messageId)") }
    func sendReply(to card: EmailCard, body: String) async throws { try record("reply:\(card.id)") }
}

enum TestStorage {
    static func makeDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mailswipe-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

/// Remplace le centre de notifications : enregistre ce qui serait planifié, ne demande jamais d'autorisation.
final class RecordingNotifications: NotificationScheduling {
    private(set) var permissionRequests = 0
    private(set) var scheduled: [(id: String, title: String, body: String, at: Date)] = []
    private(set) var cancelled: [String] = []

    func requestPermission() { permissionRequests += 1 }
    func schedule(id: String, title: String, body: String, at date: Date) { scheduled.append((id, title, body, date)) }
    func cancel(ids: [String]) { cancelled += ids }
}
