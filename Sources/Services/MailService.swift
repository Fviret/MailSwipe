import Foundation

/// Accès à une boîte mail. Implémenté par `GmailAPI` (réel) et `MockMailService` (démo / tests).
protocol MailService {
    func fetchInbox() async throws -> [EmailCard]
    func trash(messageId: String) async throws
    func archive(messageId: String) async throws
    func snooze(messageId: String) async throws
    func unsnooze(messageId: String) async throws
    func sendReply(to card: EmailCard, body: String) async throws
}

/// Service du mode démo : aucune requête réseau.
struct MockMailService: MailService {
    func fetchInbox() async throws -> [EmailCard] { MockData.inbox() }
    func trash(messageId: String) async throws {}
    func archive(messageId: String) async throws {}
    func snooze(messageId: String) async throws {}
    func unsnooze(messageId: String) async throws {}
    func sendReply(to card: EmailCard, body: String) async throws {}
}
