import Foundation

struct SnoozeItem: Identifiable, Codable, Equatable {
    let id: String
    let card: SnoozedCardData
    let wakeAt: Date
}

/// Version codable de EmailCard (pour la persistance locale des mails snoozés).
struct SnoozedCardData: Codable, Equatable {
    let threadId: String
    let subject: String
    let snippet: String
    let senderName: String
    let senderEmail: String
    let date: Date
    let isUnread: Bool

    init(from card: EmailCard) {
        threadId = card.threadId
        subject = card.subject
        snippet = card.snippet
        senderName = card.senderName
        senderEmail = card.senderEmail
        date = card.date
        isUnread = card.isUnread
    }

    func asEmailCard(id: String) -> EmailCard {
        EmailCard(
            id: id,
            threadId: threadId,
            subject: subject,
            snippet: snippet,
            senderName: senderName,
            senderEmail: senderEmail,
            date: date,
            isUnread: isUnread
        )
    }
}

enum SnoozeDuration: CaseIterable, Identifiable {
    case oneHour, thisEvening, tomorrowMorning, nextWeek

    var id: Self { self }

    var label: String {
        switch self {
        case .oneHour: return "Dans 1 heure"
        case .thisEvening: return "Ce soir (18h)"
        case .tomorrowMorning: return "Demain matin (8h)"
        case .nextWeek: return "La semaine prochaine"
        }
    }

    var symbolName: String {
        switch self {
        case .oneHour: return "clock"
        case .thisEvening: return "moon.stars"
        case .tomorrowMorning: return "sunrise"
        case .nextWeek: return "calendar"
        }
    }

    func resolvedDate(from now: Date = Date()) -> Date {
        let calendar = Calendar.current
        switch self {
        case .oneHour:
            return calendar.date(byAdding: .hour, value: 1, to: now) ?? now
        case .thisEvening:
            var comps = calendar.dateComponents([.year, .month, .day], from: now)
            comps.hour = 18
            comps.minute = 0
            let candidate = calendar.date(from: comps) ?? now
            return candidate > now ? candidate : (calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate)
        case .tomorrowMorning:
            var comps = calendar.dateComponents([.year, .month, .day], from: now)
            comps.hour = 8
            comps.minute = 0
            let today8am = calendar.date(from: comps) ?? now
            let base = today8am > now ? now : (calendar.date(byAdding: .day, value: 1, to: now) ?? now)
            var comps2 = calendar.dateComponents([.year, .month, .day], from: base)
            comps2.hour = 8
            comps2.minute = 0
            return calendar.date(from: comps2) ?? now
        case .nextWeek:
            return calendar.date(byAdding: .day, value: 7, to: now) ?? now
        }
    }
}
