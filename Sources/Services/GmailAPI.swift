import Foundation

/// Client minimal pour l'API REST Gmail (users.messages.*).
final class GmailAPI {
    private let auth: AuthManager
    private let baseURL = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me")!

    init(auth: AuthManager) {
        self.auth = auth
    }

    func fetchInbox(maxResults: Int = 20) async throws -> [EmailCard] {
        var components = URLComponents(url: baseURL.appendingPathComponent("messages"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "maxResults", value: String(maxResults)),
            URLQueryItem(name: "labelIds", value: "INBOX"),
            URLQueryItem(name: "q", value: "in:inbox"),
        ]
        let listData = try await get(components.url!)
        let list = try JSONDecoder().decode(MessageListResponse.self, from: listData)
        guard let messages = list.messages, !messages.isEmpty else { return [] }

        return try await withThrowingTaskGroup(of: EmailCard?.self) { group in
            for message in messages {
                group.addTask { try? await self.fetchCard(id: message.id) }
            }
            var results: [EmailCard] = []
            for try await card in group {
                if let card { results.append(card) }
            }
            return results.sorted { $0.date > $1.date }
        }
    }

    private func fetchCard(id: String) async throws -> EmailCard {
        var components = URLComponents(url: baseURL.appendingPathComponent("messages/\(id)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "format", value: "metadata"),
            URLQueryItem(name: "metadataHeaders", value: "Subject"),
            URLQueryItem(name: "metadataHeaders", value: "From"),
            URLQueryItem(name: "metadataHeaders", value: "Date"),
        ]
        let data = try await get(components.url!)
        let message = try JSONDecoder().decode(MessageDetail.self, from: data)
        return message.asEmailCard()
    }

    func trash(messageId: String) async throws {
        _ = try await post(baseURL.appendingPathComponent("messages/\(messageId)/trash"), body: Data())
    }

    func archive(messageId: String) async throws {
        let body = try JSONEncoder().encode(ModifyRequest(removeLabelIds: ["INBOX"], addLabelIds: []))
        _ = try await post(baseURL.appendingPathComponent("messages/\(messageId)/modify"), body: body)
    }

    func snoozeAway(messageId: String) async throws {
        // Retire simplement le mail de la boîte de réception ; SnoozeScheduler
        // se charge de le refaire réapparaître côté client à l'heure choisie.
        try await archive(messageId: messageId)
    }

    func unsnooze(messageId: String) async throws {
        let body = try JSONEncoder().encode(ModifyRequest(removeLabelIds: [], addLabelIds: ["INBOX"]))
        _ = try await post(baseURL.appendingPathComponent("messages/\(messageId)/modify"), body: body)
    }

    func sendReply(to card: EmailCard, body text: String) async throws {
        let raw = Self.buildMIMEReply(to: card, bodyText: text)
        let payload = try JSONEncoder().encode(SendRequest(raw: raw, threadId: card.threadId))
        _ = try await post(baseURL.appendingPathComponent("messages/send"), body: payload)
    }

    // MARK: - Networking

    private func get(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(try await auth.validAccessToken())", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response, data: data)
        return data
    }

    private func post(_ url: URL, body: Data) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("Bearer \(try await auth.validAccessToken())", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response, data: data)
        return data
    }

    private static func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GmailError.requestFailed(body)
        }
    }

    private static func buildMIMEReply(to card: EmailCard, bodyText: String) -> String {
        let subject = card.subject.hasPrefix("Re:") ? card.subject : "Re: \(card.subject)"
        let message = """
        To: \(card.senderEmail)
        Subject: \(subject)
        Content-Type: text/plain; charset="UTF-8"

        \(bodyText)
        """
        let data = Data(message.utf8)
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Wire models

private struct MessageListResponse: Decodable {
    struct Item: Decodable { let id: String }
    let messages: [Item]?
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
        let from = header("From") ?? "Inconnu"
        let (name, email) = Self.parseSender(from)
        return EmailCard(
            id: id,
            threadId: threadId,
            subject: header("Subject") ?? "(sans objet)",
            snippet: snippet ?? "",
            senderName: name,
            senderEmail: email,
            date: Self.parseDate(header("Date")),
            isUnread: labelIds?.contains("UNREAD") ?? false
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
