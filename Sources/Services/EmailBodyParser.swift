import Foundation

/// Arbre MIME renvoyé par Gmail (`format=full`).
struct GmailPart: Decodable {
    struct Body: Decodable { let data: String? }
    let mimeType: String?
    let filename: String?
    let body: Body?
    let parts: [GmailPart]?
}

struct GmailFullMessage: Decodable {
    let payload: GmailPart
}

/// Extrait un texte lisible d'un mail : le `text/plain` s'il existe, sinon le HTML nettoyé.
enum EmailBodyParser {
    static let maxLength = 20_000

    static func text(from payload: GmailPart) -> String {
        var plain: [String] = []
        var html: [String] = []
        collect(payload, plain: &plain, html: &html)

        let text = plain.isEmpty ? html.map(htmlToText).joined(separator: "\n\n") : plain.joined(separator: "\n\n")
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: #"[ \t]+\n"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > maxLength else { return normalized }
        return String(normalized.prefix(maxLength)) + "…"
    }

    private static func collect(_ part: GmailPart, plain: inout [String], html: inout [String]) {
        let isAttachment = !(part.filename ?? "").isEmpty
        if !isAttachment, let data = part.body?.data, let decoded = decodeBase64URL(data) {
            switch part.mimeType?.lowercased() {
            case "text/plain": plain.append(decoded)
            case "text/html": html.append(decoded)
            default: break
            }
        }
        for child in part.parts ?? [] { collect(child, plain: &plain, html: &html) }
    }

    static func decodeBase64URL(_ string: String) -> String? {
        var base64 = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64) else { return nil }
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
    }

    static func htmlToText(_ html: String) -> String {
        var text = html
        let rules: [(String, String)] = [
            (#"(?is)<(style|script|head)\b.*?</\1>"#, ""),
            (#"(?s)<!--.*?-->"#, ""),
            (#"(?i)<br\s*/?>"#, "\n"),
            (#"(?i)<li\b[^>]*>"#, "\n• "),
            (#"(?i)</(p|div|tr|h[1-6]|ul|ol|table|blockquote)>"#, "\n\n"),
            (#"<[^>]+>"#, ""),
        ]
        for (pattern, replacement) in rules {
            text = text.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        return decodeEntities(text)
    }

    private static func decodeEntities(_ text: String) -> String {
        var result = text
        let named = ["&nbsp;": " ", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&apos;": "'", "&#39;": "'", "&hellip;": "…", "&euro;": "€"]
        for (entity, value) in named { result = result.replacingOccurrences(of: entity, with: value) }

        // Entités numériques : &#233; et &#xE9;
        let numeric = try? NSRegularExpression(pattern: #"&#(x?)([0-9A-Fa-f]+);"#)
        let ns = result as NSString
        var output = ""
        var last = 0
        for match in numeric?.matches(in: result, range: NSRange(location: 0, length: ns.length)) ?? [] {
            output += ns.substring(with: NSRange(location: last, length: match.range.location - last))
            let isHex = ns.substring(with: match.range(at: 1)) == "x"
            let digits = ns.substring(with: match.range(at: 2))
            if let code = UInt32(digits, radix: isHex ? 16 : 10), let scalar = Unicode.Scalar(code) {
                output += String(Character(scalar))
            }
            last = match.range.location + match.range.length
        }
        output += ns.substring(from: last)
        return output.replacingOccurrences(of: "&amp;", with: "&")
    }
}
