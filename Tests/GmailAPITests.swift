import XCTest
@testable import MailSwipe

final class GmailAPISnoozeTests: XCTestCase {
    private var tokens: FakeTokenProvider!
    private var api: GmailAPI!

    override func setUp() {
        StubURLProtocol.reset()
        tokens = FakeTokenProvider()
        api = GmailAPI(auth: tokens, session: StubURLProtocol.session())
    }

    private func modifyBody(at index: Int) throws -> (add: [String], remove: [String]) {
        let call = StubURLProtocol.recorded[index]
        let json = try JSONSerialization.jsonObject(with: call.body ?? Data()) as? [String: [String]]
        return (json?["addLabelIds"] ?? [], json?["removeLabelIds"] ?? [])
    }

    func testSnoozeCreatesLabelThenMovesMailOutOfInbox() async throws {
        StubURLProtocol.handler = { request in
            let path = request.url!.path
            if path.hasSuffix("/labels") && request.httpMethod != "POST" {
                return (200, Data(#"{"labels":[{"id":"INBOX","name":"INBOX"}]}"#.utf8))
            }
            if path.hasSuffix("/labels") { return (200, Data(#"{"id":"Label_9","name":"MailSwipe/Snoozed"}"#.utf8)) }
            return (200, Data("{}".utf8))
        }
        try await api.snooze(messageId: "m1")

        let calls = StubURLProtocol.recorded
        XCTAssertEqual(calls.map(\.method), ["GET", "POST", "POST"])
        XCTAssertTrue(calls[2].url.path.hasSuffix("/messages/m1/modify"))
        let body = try modifyBody(at: 2)
        XCTAssertEqual(body.add, ["Label_9"])
        XCTAssertEqual(body.remove, ["INBOX"])
    }

    func testExistingLabelIsReusedAndNotRecreated() async throws {
        StubURLProtocol.handler = { request in
            if request.url!.path.hasSuffix("/labels") {
                return (200, Data(#"{"labels":[{"id":"Label_7","name":"MailSwipe/Snoozed"}]}"#.utf8))
            }
            return (200, Data("{}".utf8))
        }
        try await api.snooze(messageId: "m1")
        XCTAssertEqual(StubURLProtocol.recorded.map(\.method), ["GET", "POST"], "pas de création de libellé")
        XCTAssertEqual(try modifyBody(at: 1).add, ["Label_7"])
    }

    func testLabelIsLookedUpOnlyOncePerSession() async throws {
        StubURLProtocol.handler = { request in
            if request.url!.path.hasSuffix("/labels") { return (200, Data(#"{"labels":[{"id":"Label_7","name":"MailSwipe/Snoozed"}]}"#.utf8)) }
            return (200, Data("{}".utf8))
        }
        try await api.snooze(messageId: "m1")
        try await api.snooze(messageId: "m2")
        XCTAssertEqual(StubURLProtocol.recorded.filter { $0.url.path.hasSuffix("/labels") }.count, 1)
    }

    func testUnsnoozePutsMailBackInInbox() async throws {
        StubURLProtocol.handler = { request in
            if request.url!.path.hasSuffix("/labels") { return (200, Data(#"{"labels":[{"id":"Label_7","name":"MailSwipe/Snoozed"}]}"#.utf8)) }
            return (200, Data("{}".utf8))
        }
        try await api.unsnooze(messageId: "m1")
        let body = try modifyBody(at: 1)
        XCTAssertEqual(body.add, ["INBOX"])
        XCTAssertEqual(body.remove, ["Label_7"])
    }
}

final class GmailAPIAuthRetryTests: XCTestCase {
    override func setUp() { StubURLProtocol.reset() }

    func testRetriesOnceAfter401WithFreshToken() async throws {
        let tokens = FakeTokenProvider()
        var calls = 0
        StubURLProtocol.handler = { _ in
            calls += 1
            return calls == 1 ? (401, Data()) : (200, Data("{}".utf8))
        }
        let api = GmailAPI(auth: tokens, session: StubURLProtocol.session())
        try await api.archive(messageId: "m1")
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(tokens.invalidated, 1)
        XCTAssertEqual(tokens.expired, 0)
    }

    func testSecondUnauthorizedSignsOut() async {
        let tokens = FakeTokenProvider()
        StubURLProtocol.handler = { _ in (401, Data()) }
        let api = GmailAPI(auth: tokens, session: StubURLProtocol.session())
        do {
            try await api.archive(messageId: "m1")
            XCTFail("doit échouer")
        } catch {
            XCTAssertEqual(error as? GmailError, .sessionExpired)
        }
        XCTAssertEqual(StubURLProtocol.recorded.count, 2, "une seule nouvelle tentative")
        XCTAssertEqual(tokens.expired, 1)
    }
}
