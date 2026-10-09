import Foundation

/// Client minimal pour l'API REST Gmail (users.messages.*).
final class GmailAPI: MailService {
    static let snoozeLabelName = "MailSwipe/Snoozed"

    private let auth: AccessTokenProviding
    private let session: URLSession
    private let baseURL: URL
    private let snoozeLabel = LabelCache()

    init(
        auth: AccessTokenProviding,
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me")!
    ) {
        self.auth = auth
        self.session = session
        self.baseURL = baseURL
    }

    func fetchInbox(pageToken: String?) async throws -> MailPage {
        try await fetchInbox(maxResults: 20, pageToken: pageToken)
    }

    private func fetchInbox(maxResults: Int, pageToken: String?) async throws -> MailPage {
        var components = URLComponents(url: baseURL.appendingPathComponent("messages"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "maxResults", value: String(maxResults)),
            URLQueryItem(name: "labelIds", value: "INBOX"),
            URLQueryItem(name: "q", value: "in:inbox"),
        ]
        if let pageToken { components.queryItems?.append(URLQueryItem(name: "pageToken", value: pageToken)) }
        let listData = try await get(components.url!)
        let list = try JSONDecoder().decode(MessageListResponse.self, from: listData)
        guard let messages = list.messages, !messages.isEmpty else {
            return MailPage(cards: [], nextPageToken: list.nextPageToken)
        }

        return try await withThrowingTaskGroup(of: Result<EmailCard, Error>.self) { group in
            for message in messages {
                group.addTask {
                    do { return .success(try await self.fetchCard(id: message.id)) }
                    catch { return .failure(error) }
                }
            }
            var cards: [EmailCard] = []
            var firstError: Error?
            var failed = 0
            for try await result in group {
                switch result {
                case .success(let card): cards.append(card)
                case .failure(let error):
                    failed += 1
                    firstError = firstError ?? error
                }
            }
            // Tout a échoué : on remonte l'erreur au lieu d'afficher une fausse « boîte vide ».
            if cards.isEmpty, let firstError { throw firstError }
            return MailPage(
                cards: cards.sorted { $0.date > $1.date },
                nextPageToken: list.nextPageToken,
                failedCount: failed
            )
        }
    }

    private func fetchCard(id: String) async throws -> EmailCard {
        var components = URLComponents(url: baseURL.appendingPathComponent("messages/\(id)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "format", value: "metadata"),
            URLQueryItem(name: "metadataHeaders", value: "Subject"),
            URLQueryItem(name: "metadataHeaders", value: "From"),
            URLQueryItem(name: "metadataHeaders", value: "Date"),
            URLQueryItem(name: "metadataHeaders", value: "Message-ID"),
            URLQueryItem(name: "metadataHeaders", value: "References"),
            URLQueryItem(name: "metadataHeaders", value: "Reply-To"),
        ]
        let data = try await get(components.url!)
        let message = try JSONDecoder().decode(MessageDetail.self, from: data)
        return message.asEmailCard()
    }

    func fetchBody(messageId: String) async throws -> String {
        var components = URLComponents(url: baseURL.appendingPathComponent("messages/\(messageId)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "format", value: "full")]
        let data = try await get(components.url!)
        let message = try JSONDecoder().decode(GmailFullMessage.self, from: data)
        return EmailBodyParser.text(from: message.payload)
    }

    func trash(messageId: String) async throws {
        _ = try await post(baseURL.appendingPathComponent("messages/\(messageId)/trash"), body: Data())
    }

    func archive(messageId: String) async throws {
        let body = try JSONEncoder().encode(ModifyRequest(removeLabelIds: ["INBOX"], addLabelIds: []))
        _ = try await post(baseURL.appendingPathComponent("messages/\(messageId)/modify"), body: body)
    }

    /// Gmail n'a pas d'API de snooze : le mail quitte la boîte de réception mais reste retrouvable
    /// dans le libellé « MailSwipe/Snoozed » (jamais « perdu » dans Tous les messages).
    func snooze(messageId: String) async throws {
        let labelId = try await snoozeLabelId()
        let body = try JSONEncoder().encode(ModifyRequest(removeLabelIds: ["INBOX"], addLabelIds: [labelId]))
        _ = try await post(baseURL.appendingPathComponent("messages/\(messageId)/modify"), body: body)
    }

    func unsnooze(messageId: String) async throws {
        let labelId = try await snoozeLabelId()
        let body = try JSONEncoder().encode(ModifyRequest(removeLabelIds: [labelId], addLabelIds: ["INBOX"]))
        _ = try await post(baseURL.appendingPathComponent("messages/\(messageId)/modify"), body: body)
    }

    private func snoozeLabelId() async throws -> String {
        try await snoozeLabel.id {
            let listData = try await self.get(self.baseURL.appendingPathComponent("labels"))
            let labels = try JSONDecoder().decode(LabelListResponse.self, from: listData).labels ?? []
            if let existing = labels.first(where: { $0.name == Self.snoozeLabelName }) { return existing.id }

            let payload = try JSONEncoder().encode(CreateLabelRequest(name: Self.snoozeLabelName))
            let created = try await self.post(self.baseURL.appendingPathComponent("labels"), body: payload)
            return try JSONDecoder().decode(LabelResponse.self, from: created).id
        }
    }

    func sendReply(to card: EmailCard, body text: String) async throws {
        let raw = try ReplyBuilder.rawMessage(for: card, body: text)
        let payload = try JSONEncoder().encode(SendRequest(raw: raw, threadId: card.threadId))
        _ = try await post(baseURL.appendingPathComponent("messages/send"), body: payload)
    }

    // MARK: - Networking

    private func get(_ url: URL) async throws -> Data {
        try await perform { token in
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            return request
        }
    }

    private func post(_ url: URL, body: Data) async throws -> Data {
        try await perform { token in
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = body
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            return request
        }
    }

    /// Une seule nouvelle tentative après un 401 (jeton d'accès périmé côté Google) ; au second 401, on déconnecte.
    private func perform(_ makeRequest: (String) -> URLRequest) async throws -> Data {
        for attempt in 0..<2 {
            let token = try await auth.validAccessToken()
            let (data, response) = try await session.data(for: makeRequest(token))
            if (response as? HTTPURLResponse)?.statusCode == 401 {
                if attempt == 0 {
                    await auth.invalidateAccessToken()
                    continue
                }
                await auth.handleSessionExpired()
            }
            try GmailError.validate(response, data: data)
            return data
        }
        throw GmailError.sessionExpired
    }
}

// MARK: - Wire models

private struct MessageListResponse: Decodable {
    struct Item: Decodable { let id: String }
    let messages: [Item]?
    let nextPageToken: String?
}

/// Mémorise l'identifiant du libellé de snooze pour ne le chercher/créer qu'une fois.
private actor LabelCache {
    private var cached: String?

    func id(resolve: () async throws -> String) async throws -> String {
        if let cached { return cached }
        let resolved = try await resolve()
        cached = resolved
        return resolved
    }
}

private struct LabelResponse: Decodable { let id: String; let name: String? }
private struct LabelListResponse: Decodable { let labels: [LabelResponse]? }

private struct CreateLabelRequest: Encodable {
    let name: String
    let labelListVisibility = "labelShow"
    let messageListVisibility = "show"
}

private struct ModifyRequest: Encodable {
    let removeLabelIds: [String]
    let addLabelIds: [String]
}

private struct SendRequest: Encodable {
    let raw: String
    let threadId: String
}

private struct MessageDetail: Decodable {
    struct Payload: Decodable {
        struct Header: Decodable { let name: String; let value: String }
        let headers: [Header]
    }
    let id: String
    let threadId: String
    let snippet: String?
    let payload: Payload
    let labelIds: [String]?

    func header(_ name: String) -> String? {
        payload.headers.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    func asEmailCard() -> EmailCard {
        let from = header("From") ?? String(localized: "Inconnu")
        let (name, email) = Self.parseSender(from)
        return EmailCard(
            id: id,
            threadId: threadId,
            subject: header("Subject") ?? String(localized: "(sans objet)"),
            snippet: snippet ?? "",
            senderName: name,
            senderEmail: email,
            date: Self.parseDate(header("Date")),
            isUnread: labelIds?.contains("UNREAD") ?? false,
            messageIdHeader: header("Message-ID"),
            references: header("References"),
            replyTo: header("Reply-To")
        )
    }

    private static func parseSender(_ raw: String) -> (name: String, email: String) {
        if let openIdx = raw.firstIndex(of: "<"), let closeIdx = raw.firstIndex(of: ">") {
            let name = raw[raw.startIndex..<openIdx]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            let email = String(raw[raw.index(after: openIdx)..<closeIdx])
            return (name.isEmpty ? email : name, email)
        }
        return (raw, raw)
    }

    private static func parseDate(_ raw: String?) -> Date {
        guard let raw else { return Date() }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, d MMM yyyy HH:mm:ss Z"
        return formatter.date(from: raw) ?? Date()
    }
}
