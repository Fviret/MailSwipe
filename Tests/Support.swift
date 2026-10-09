import Foundation
@testable import MailSwipe

/// Service de test : peut échouer sur demande et enregistre les appels.
final class SpyMailService: MailService, @unchecked Sendable {
    struct Failure: LocalizedError { var errorDescription: String? { "boom" } }

    var failing = false
    var cards: [EmailCard] = MockData.inbox()
    private(set) var calls: [String] = []

    private func record(_ name: String) throws {
        calls.append(name)
        if failing { throw Failure() }
    }

    func fetchInbox() async throws -> [EmailCard] { try record("fetchInbox"); return cards }
    func trash(messageId: String) async throws { try record("trash:\(messageId)") }
    func archive(messageId: String) async throws { try record("archive:\(messageId)") }
    func snooze(messageId: String) async throws { try record("snooze:\(messageId)") }
    func unsnooze(messageId: String) async throws { try record("unsnooze:\(messageId)") }
    func sendReply(to card: EmailCard, body: String) async throws { try record("reply:\(card.id)") }
}
