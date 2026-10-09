import Foundation

struct EmailCard: Identifiable, Equatable, Codable {
    let id: String
    let threadId: String
    var subject: String
    var snippet: String
    var senderName: String
    var senderEmail: String
    var date: Date
    var isUnread: Bool
    /// En-têtes utiles pour répondre dans le bon fil de discussion.
    var messageIdHeader: String? = nil
    var references: String? = nil
    var replyTo: String? = nil

    static func == (lhs: EmailCard, rhs: EmailCard) -> Bool {
        lhs.id == rhs.id
    }
}

enum SwipeDirection {
    case left, right, up, down
}

extension SwipeDirection {
    var actionTitle: String {
        switch self {
        case .right: return String(localized: "Répondre")
        case .left: return String(localized: "Supprimer")
        case .up: return String(localized: "Archiver")
        case .down: return String(localized: "Snoozer")
        }
    }

    var symbolName: String {
        switch self {
        case .right: return "arrowshape.turn.up.left.fill"
        case .left: return "trash.fill"
        case .up: return "archivebox.fill"
        case .down: return "clock.fill"
        }
    }
}
