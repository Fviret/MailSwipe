import Foundation

struct EmailCard: Identifiable, Equatable {
    let id: String
    let threadId: String
    var subject: String
    var snippet: String
    var senderName: String
    var senderEmail: String
    var date: Date
    var isUnread: Bool

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
        case .right: return "Répondre"
        case .left: return "Supprimer"
        case .up: return "Archiver"
        case .down: return "Snoozer"
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
