import XCTest
@testable import MailSwipe

final class EmailBodyParserTests: XCTestCase {
    private func b64url(_ s: String) -> String {
        Data(s.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    private func part(_ mime: String, _ text: String? = nil, filename: String? = nil, parts: [GmailPart]? = nil) -> GmailPart {
        GmailPart(mimeType: mime, filename: filename, body: text.map { GmailPart.Body(data: b64url($0)) }, parts: parts)
    }

    func testPlainTextIsPreferredOverHTML() {
        let tree = part("multipart/alternative", parts: [
            part("text/plain", "Version texte"),
            part("text/html", "<p>Version <b>HTML</b></p>"),
        ])
        XCTAssertEqual(EmailBodyParser.text(from: tree), "Version texte")
    }

    func testHTMLFallbackIsConvertedToReadableText() {
        let html = "<html><head><style>p{color:red}</style></head><body><p>Bonjour &amp; bienvenue</p><ul><li>Un</li><li>Deux</li></ul><script>alert(1)</script></body></html>"
        let text = EmailBodyParser.text(from: part("text/html", html))
        XCTAssertTrue(text.contains("Bonjour & bienvenue"))
        XCTAssertTrue(text.contains("• Un"))
        XCTAssertTrue(text.contains("• Deux"))
        XCTAssertFalse(text.contains("color:red"))
        XCTAssertFalse(text.contains("alert"))
        XCTAssertFalse(text.contains("<"))
    }

    func testNumericAndNamedEntities() {
        let text = EmailBodyParser.htmlToText("caf&#233; &#xE9;t&#233; &lt;3 &quot;ok&quot; 5&nbsp;&euro;")
        XCTAssertEqual(text, "café été <3 \"ok\" 5 €")
    }

    func testAttachmentsAreIgnored() {
        let tree = part("multipart/mixed", parts: [
            part("text/plain", "Le message"),
            part("text/plain", "contenu du fichier joint", filename: "notes.txt"),
        ])
        XCTAssertEqual(EmailBodyParser.text(from: tree), "Le message")
    }

    func testNestedMultipartWithAccentsAndEmoji() {
        let tree = part("multipart/mixed", parts: [
            part("multipart/related", parts: [part("multipart/alternative", parts: [part("text/plain", "À bientôt 👋")])]),
        ])
        XCTAssertEqual(EmailBodyParser.text(from: tree), "À bientôt 👋")
    }

    func testBlankLinesAreCollapsed() {
        XCTAssertEqual(EmailBodyParser.text(from: part("text/plain", "a\n\n\n\n\nb   \n")), "a\n\nb")
    }

    func testVeryLongBodyIsTruncated() {
        let text = EmailBodyParser.text(from: part("text/plain", String(repeating: "x", count: 50_000)))
        XCTAssertEqual(text.count, EmailBodyParser.maxLength + 1)
        XCTAssertTrue(text.hasSuffix("…"))
    }

    func testInvalidBase64IsSkippedWithoutCrashing() {
        let broken = GmailPart(mimeType: "text/plain", filename: nil, body: .init(data: "***"), parts: nil)
        XCTAssertEqual(EmailBodyParser.text(from: broken), "")
    }
}

final class GmailBodyFetchTests: XCTestCase {
    override func setUp() { StubURLProtocol.reset() }

    func testFetchBodyRequestsFullFormatAndDecodesText() async throws {
        let encoded = Data("Bonjour tout le monde".utf8).base64EncodedString()
        StubURLProtocol.handler = { _ in
            (200, Data(#"{"payload":{"mimeType":"text/plain","body":{"data":"\#(encoded)"}}}"#.utf8))
        }
        let api = GmailAPI(auth: FakeTokenProvider(), session: StubURLProtocol.session())
        let text = try await api.fetchBody(messageId: "m1")
        XCTAssertEqual(text, "Bonjour tout le monde")
        XCTAssertTrue(StubURLProtocol.recorded[0].url.absoluteString.contains("format=full"))
    }
}

@MainActor
final class BodyCacheTests: XCTestCase {
    func testBodyIsFetchedOncePerMail() async throws {
        let spy = SpyMailService()
        let store = EmailStore(auth: AuthManager(), mock: spy, undoDelay: 0, storageDirectory: TestStorage.makeDirectory(), notifications: RecordingNotifications())
        await store.loadInbox()
        let card = store.inbox[0]
        _ = try await store.body(for: card)
        _ = try await store.body(for: card)
        XCTAssertEqual(spy.calls.filter { $0 == "body:\(card.id)" }.count, 1)
    }

    func testBodyFailureIsPropagatedAndNotCached() async {
        let spy = SpyMailService()
        let store = EmailStore(auth: AuthManager(), mock: spy, undoDelay: 0, storageDirectory: TestStorage.makeDirectory(), notifications: RecordingNotifications())
        await store.loadInbox()
        spy.failing = true
        do { _ = try await store.body(for: store.inbox[0]); XCTFail() } catch {}
        spy.failing = false
        let text = try? await store.body(for: store.inbox[0])
        XCTAssertNotNil(text)
    }
}
