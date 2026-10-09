import XCTest
@testable import MailSwipe

final class ReplyBuilderTests: XCTestCase {
    private func card(
        email: String = "camille@exemple.fr",
        subject: String = "Point projet",
        messageId: String? = nil,
        references: String? = nil,
        replyTo: String? = nil
    ) -> EmailCard {
        EmailCard(id: "1", threadId: "t", subject: subject, snippet: "", senderName: "Camille", senderEmail: email,
                  date: Date(), isUnread: false, messageIdHeader: messageId, references: references, replyTo: replyTo)
    }

    private func decode(_ raw: String) -> String {
        var base64 = raw.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        return String(data: Data(base64Encoded: base64)!, encoding: .utf8)!
    }

    private func bodyText(of message: String) -> String {
        let encoded = message.components(separatedBy: "\r\n\r\n").last!.replacingOccurrences(of: "\r\n", with: "")
        return String(data: Data(base64Encoded: encoded)!, encoding: .utf8)!
    }

    func testBasicHeadersAndCRLF() throws {
        let message = decode(try ReplyBuilder.rawMessage(for: card(), body: "Bonjour"))
        XCTAssertTrue(message.contains("To: camille@exemple.fr\r\n"))
        XCTAssertTrue(message.contains("Subject: Re: Point projet\r\n"))
        XCTAssertTrue(message.contains("MIME-Version: 1.0\r\n"))
        XCTAssertTrue(message.contains("Content-Transfer-Encoding: base64\r\n"))
        XCTAssertFalse(message.replacingOccurrences(of: "\r\n", with: "").contains("\n"))
    }

    func testThreadingHeaders() throws {
        let c = card(messageId: "<abc@mail.x>", references: "<root@mail.x>")
        let message = decode(try ReplyBuilder.rawMessage(for: c, body: "ok"))
        XCTAssertTrue(message.contains("In-Reply-To: <abc@mail.x>\r\n"))
        XCTAssertTrue(message.contains("References: <root@mail.x> <abc@mail.x>\r\n"))
    }

    func testNoThreadingHeadersWithoutMessageId() throws {
        let message = decode(try ReplyBuilder.rawMessage(for: card(), body: "ok"))
        XCTAssertFalse(message.contains("In-Reply-To"))
    }

    func testAccentedSubjectIsEncodedPerRFC2047() throws {
        let message = decode(try ReplyBuilder.rawMessage(for: card(subject: "Ta facture Septembre — élevée"), body: "ok"))
        let subjectLine = message.components(separatedBy: "\r\n").first { $0.hasPrefix("Subject:") }!
        XCTAssertTrue(subjectLine.contains("=?UTF-8?B?"))
        XCTAssertTrue(subjectLine.allSatisfy { $0.isASCII }, "aucun octet non ASCII brut dans l'en-tête")
    }

    func testLongNonASCIISubjectIsSplitIntoShortEncodedWords() {
        let subject = "Re: " + String(repeating: "éàü☕ ", count: 30)
        let encoded = ReplyBuilder.encodeHeader(subject)
        for word in encoded.components(separatedBy: "\r\n ") {
            XCTAssertLessThanOrEqual(word.count, 75)
        }
    }

    func testEncodedSubjectRoundTrips() {
        let subject = "Réunion à 14h ☕"
        let words = ReplyBuilder.encodeHeader(subject).components(separatedBy: "\r\n ")
        let decoded = words.map { word -> String in
            let b64 = word.dropFirst("=?UTF-8?B?".count).dropLast(2)
            return String(data: Data(base64Encoded: String(b64))!, encoding: .utf8)!
        }.joined()
        XCTAssertEqual(decoded, subject)
    }

    func testBodyKeepsAccentsEmojiAndNewlines() throws {
        let body = "Bonjour,\nMerci beaucoup 🙏 — à bientôt !\n\nFlorian"
        let message = decode(try ReplyBuilder.rawMessage(for: card(), body: body))
        XCTAssertEqual(bodyText(of: message), body.replacingOccurrences(of: "\n", with: "\r\n"))
    }

    func testHeaderInjectionInSubjectIsNeutralised() throws {
        let c = card(subject: "Hello\r\nBcc: victime@evil.com")
        let message = decode(try ReplyBuilder.rawMessage(for: c, body: "x"))
        let headerBlock = message.components(separatedBy: "\r\n\r\n")[0]
        XCTAssertFalse(headerBlock.components(separatedBy: "\r\n").contains { $0.hasPrefix("Bcc:") })
    }

    func testReplyToIsPreferredOverSender() throws {
        let c = card(email: "notifications@service.com", replyTo: "Support <support@service.com>")
        XCTAssertEqual(ReplyBuilder.replyAddress(for: c), "support@service.com")
        XCTAssertTrue(ReplyBuilder.canReply(c))
        XCTAssertTrue(decode(try ReplyBuilder.rawMessage(for: c, body: "x")).contains("To: support@service.com\r\n"))
    }

    func testNoReplyAddressesAreDetected() {
        for email in ["noreply@x.com", "no-reply@x.com", "no_reply@x.com", "do-not-reply@x.com", "ne-pas-repondre@x.fr", "MAILER-DAEMON@x.com"] {
            XCTAssertFalse(ReplyBuilder.canReply(card(email: email)), email)
        }
        XCTAssertTrue(ReplyBuilder.canReply(card(email: "florian@x.com")))
    }

    func testOnlyTheFirstAddressOfAListIsUsed() throws {
        let message = decode(try ReplyBuilder.rawMessage(for: card(email: "x@y.com, z@evil.com"), body: "x"))
        XCTAssertTrue(message.contains("To: x@y.com\r\n"))
        XCTAssertFalse(message.contains("evil"))
    }

    func testAlreadyPrefixedSubjectIsNotDoubled() {
        XCTAssertEqual(ReplyBuilder.subject(for: card(subject: "RE: Devis")), "RE: Devis")
        XCTAssertEqual(ReplyBuilder.subject(for: card(subject: "Devis")), "Re: Devis")
    }

    func testInvalidRecipientIsRejected() {
        for email in ["pas-une-adresse", "a@b", "a b@c.com", "a@b.com;c@evil.com"] {
            XCTAssertThrowsError(try ReplyBuilder.rawMessage(for: card(email: email), body: "x"), email)
        }
    }
}

final class GmailAPIFetchTests: XCTestCase {
    override func setUp() { StubURLProtocol.reset() }

    func testFetchRequestsThreadingHeadersAndPageToken() async throws {
        StubURLProtocol.handler = { request in
            let path = request.url!.path
            if path.hasSuffix("/messages") {
                return (200, Data(#"{"messages":[{"id":"m1"}],"nextPageToken":"NEXT"}"#.utf8))
            }
            return (200, Data("""
            {"id":"m1","threadId":"t1","snippet":"Salut","labelIds":["UNREAD"],"payload":{"headers":[
              {"name":"Subject","value":"Hello"},{"name":"From","value":"Camille <camille@x.fr>"},
              {"name":"Date","value":"Tue, 6 Oct 2026 10:00:00 +0200"},
              {"name":"Message-Id","value":"<abc@x.fr>"},{"name":"References","value":"<root@x.fr>"},
              {"name":"Reply-To","value":"Equipe <team@x.fr>"}]}}
            """.utf8))
        }
        let api = GmailAPI(auth: FakeTokenProvider(), session: StubURLProtocol.session())
        let page = try await api.fetchInbox(pageToken: "TOKEN")

        XCTAssertEqual(page.nextPageToken, "NEXT")
        XCTAssertEqual(page.cards.count, 1)
        let card = page.cards[0]
        XCTAssertEqual(card.senderName, "Camille")
        XCTAssertEqual(card.messageIdHeader, "<abc@x.fr>")
        XCTAssertEqual(card.references, "<root@x.fr>")
        XCTAssertEqual(card.replyTo, "Equipe <team@x.fr>")
        XCTAssertTrue(card.isUnread)

        let listURL = StubURLProtocol.recorded[0].url.absoluteString
        XCTAssertTrue(listURL.contains("pageToken=TOKEN"))
        let detailURL = StubURLProtocol.recorded.last!.url.absoluteString
        for header in ["Message-ID", "References", "Reply-To"] {
            XCTAssertTrue(detailURL.contains("metadataHeaders=\(header)"), header)
        }
    }

    func testAllMessagesFailingSurfacesAnErrorNotAnEmptyInbox() async {
        StubURLProtocol.handler = { request in
            request.url!.path.hasSuffix("/messages")
                ? (200, Data(#"{"messages":[{"id":"m1"},{"id":"m2"}]}"#.utf8))
                : (500, Data(#"{"error":{"message":"Backend Error"}}"#.utf8))
        }
        let api = GmailAPI(auth: FakeTokenProvider(), session: StubURLProtocol.session())
        do {
            _ = try await api.fetchInbox(pageToken: nil)
            XCTFail("doit lever une erreur")
        } catch {
            XCTAssertEqual(error as? GmailError, .api(status: 500, message: "Backend Error"))
        }
    }

    func testPartialFailureIsReported() async throws {
        StubURLProtocol.handler = { request in
            let url = request.url!
            if url.path.hasSuffix("/messages") { return (200, Data(#"{"messages":[{"id":"ok"},{"id":"bad"}]}"#.utf8)) }
            if url.path.hasSuffix("/bad") { return (500, Data()) }
            return (200, Data(#"{"id":"ok","threadId":"t","snippet":"s","payload":{"headers":[{"name":"From","value":"a@b.fr"}]}}"#.utf8))
        }
        let api = GmailAPI(auth: FakeTokenProvider(), session: StubURLProtocol.session())
        let page = try await api.fetchInbox(pageToken: nil)
        XCTAssertEqual(page.cards.count, 1)
        XCTAssertEqual(page.failedCount, 1)
    }
}
