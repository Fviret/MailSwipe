import Foundation

/// Une page de mails ; `nextPageToken == nil` signifie qu'il n'y en a plus.
struct MailPage {
    var cards: [EmailCard]
    var nextPageToken: String?
    /// Mails de la page qui n'ont pas pu être lus.
    var failedCount = 0
}

/// Accès à une boîte mail. Implémenté par `GmailAPI` (réel) et `MockMailService` (démo / tests).
protocol MailService {
    func fetchInbox(pageToken: String?) async throws -> MailPage
    func trash(messageId: String) async throws
    func archive(messageId: String) async throws
    func snooze(messageId: String) async throws
    func unsnooze(messageId: String) async throws
    func sendReply(to card: EmailCard, body: String) async throws
}

/// Service du mode démo : aucune requête réseau.
struct MockMailService: MailService {
    static let defaultPageSize = 6
    var pageSize = MockMailService.defaultPageSize

    func fetchInbox(pageToken: String?) async throws -> MailPage {
        let all = MockData.inbox()
        let start = min(Int(pageToken ?? "") ?? 0, all.count)
        let end = min(start + pageSize, all.count)
        return MailPage(cards: Array(all[start..<end]), nextPageToken: end < all.count ? String(end) : nil)
    }
    func trash(messageId: String) async throws {}
    func archive(messageId: String) async throws {}
    func snooze(messageId: String) async throws {}
    func unsnooze(messageId: String) async throws {}
    func sendReply(to card: EmailCard, body: String) async throws {}
}
