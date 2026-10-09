import Foundation

enum ReplyError: LocalizedError, Equatable {
    case invalidRecipient(String)

    var errorDescription: String? {
        switch self {
        case .invalidRecipient(let address): return String(localized: "Adresse de réponse invalide : \(address)")
        }
    }
}

/// Construit la réponse à un mail (RFC 5322 / MIME) et décide si on peut y répondre.
enum ReplyBuilder {
    private static let noReplyMarkers = ["noreply", "donotreply", "nepasrepondre", "mailerdaemon", "postmaster"]

    /// Adresse à laquelle répondre : `Reply-To` s'il existe, sinon l'expéditeur.
    static func replyAddress(for card: EmailCard) -> String {
        if let replyTo = card.replyTo, let address = firstAddress(in: replyTo) { return address }
        return firstAddress(in: card.senderEmail) ?? card.senderEmail
    }

    /// Faux pour les adresses « ne-pas-répondre » (sauf si le mail indique un `Reply-To`).
    static func canReply(_ card: EmailCard) -> Bool {
        if let replyTo = card.replyTo, firstAddress(in: replyTo) != nil { return true }
        let address = (firstAddress(in: card.senderEmail) ?? card.senderEmail).lowercased()
        let local = address.split(separator: "@").first.map(String.init) ?? address
        let normalized = local.filter { $0.isLetter || $0.isNumber }
        return !noReplyMarkers.contains { normalized.contains($0) }
    }

    static func subject(for card: EmailCard) -> String {
        let clean = sanitize(card.subject)
        return clean.lowercased().hasPrefix("re:") ? clean : "Re: \(clean)"
    }

    /// Message complet, encodé en base64url (format attendu par `users.messages.send`).
    static func rawMessage(for card: EmailCard, body: String) throws -> String {
        let address = replyAddress(for: card)
        guard isPlausibleAddress(address) else { throw ReplyError.invalidRecipient(address) }

        var headers = [
            "To: \(address)",
            "Subject: \(encodeHeader(subject(for: card)))",
            "MIME-Version: 1.0",
            "Content-Type: text/plain; charset=UTF-8",
            "Content-Transfer-Encoding: base64",
        ]
        if let messageId = card.messageIdHeader.map(sanitize), !messageId.isEmpty {
            headers.append("In-Reply-To: \(messageId)")
            let references = [card.references.map(sanitize), messageId].compactMap { $0 }.filter { !$0.isEmpty }
            headers.append("References: \(references.joined(separator: " "))")
        }

        let normalizedBody = body
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n", with: "\r\n")
        let wrapped = wrap76(Data(normalizedBody.utf8).base64EncodedString())
        let message = headers.joined(separator: "\r\n") + "\r\n\r\n" + wrapped + "\r\n"
        return base64URL(Data(message.utf8))
    }

    // MARK: - Détails de format

    /// RFC 2047 : un en-tête non ASCII est encodé en « encoded-words » de 75 caractères maximum.
    static func encodeHeader(_ value: String) -> String {
        guard value.contains(where: { !$0.isASCII }) else { return value }
        var words: [String] = []
        var chunk = Data()
        func flush() {
            guard !chunk.isEmpty else { return }
            words.append("=?UTF-8?B?\(chunk.base64EncodedString())?=")
            chunk = Data()
        }
        for character in value {
            let bytes = Data(String(character).utf8)
            if chunk.count + bytes.count > 45 { flush() }
            chunk.append(bytes)
        }
        flush()
        return words.joined(separator: "\r\n ")
    }

    /// Retire les retours à la ligne : empêche d'injecter un en-tête (ex. `Bcc:`) via un sujet reçu.
    static func sanitize(_ value: String) -> String {
        value.unicodeScalars
            .filter { $0 != "\r" && $0 != "\n" && $0 != "\0" }
            .map(String.init)
            .joined()
            .trimmingCharacters(in: .whitespaces)
    }

    private static func firstAddress(in value: String) -> String? {
        let first = value.split(separator: ",").first.map(String.init) ?? value
        if let open = first.firstIndex(of: "<"), let close = first.firstIndex(of: ">"), open < close {
            return sanitize(String(first[first.index(after: open)..<close]))
        }
        let trimmed = sanitize(first)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func isPlausibleAddress(_ address: String) -> Bool {
        let parts = address.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, parts[1].contains(".") else { return false }
        return !address.contains { $0.isWhitespace || "<>,;\"".contains($0) }
    }

    private static func wrap76(_ base64: String) -> String {
        var lines: [String] = []
        var index = base64.startIndex
        while index < base64.endIndex {
            let end = base64.index(index, offsetBy: 76, limitedBy: base64.endIndex) ?? base64.endIndex
            lines.append(String(base64[index..<end]))
            index = end
        }
        return lines.joined(separator: "\r\n")
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
