import XCTest
@testable import MailSwipe

final class KeychainStoreTests: XCTestCase {
    private let key = "unit-test-keychain-key"
    override func tearDown() { KeychainStore.remove(key) }

    func testRoundTrip() {
        KeychainStore.set("secret", for: key)
        XCTAssertEqual(KeychainStore.get(key), "secret")
    }

    func testSetOverwritesPreviousValue() {
        KeychainStore.set("one", for: key)
        KeychainStore.set("two", for: key)
        XCTAssertEqual(KeychainStore.get(key), "two")
    }

    func testRemoveAndMissingKey() {
        KeychainStore.set("x", for: key)
        KeychainStore.remove(key)
        XCTAssertNil(KeychainStore.get(key))
        XCTAssertNil(KeychainStore.get("unit-test-never-set"))
    }

    func testValuesWithUnicodeSurvive() {
        KeychainStore.set("clé-🔐-é", for: key)
        XCTAssertEqual(KeychainStore.get(key), "clé-🔐-é")
    }
}

final class SwipeResolverTests: XCTestCase {
    private func resolve(_ x: CGFloat, _ y: CGFloat, vx: CGFloat = 0, vy: CGFloat = 0) -> SwipeDirection? {
        SwipeResolver.resolve(translation: CGSize(width: x, height: y), velocity: CGSize(width: vx, height: vy))
    }

    func testFourDirectionsPastTheThreshold() {
        XCTAssertEqual(resolve(200, 10), .right)
        XCTAssertEqual(resolve(-200, 10), .left)
        XCTAssertEqual(resolve(10, -200), .up)
        XCTAssertEqual(resolve(10, 200), .down)
    }

    func testShortSlowDragSpringsBack() {
        XCTAssertNil(resolve(100, 0))
        XCTAssertNil(resolve(0, -129))
        XCTAssertNil(resolve(0, 0))
    }

    func testThresholdIsExclusive() {
        XCTAssertNil(resolve(130, 0))
        XCTAssertEqual(resolve(130.5, 0), .right)
    }

    func testFastFlickCommitsEvenWhenShort() {
        XCTAssertEqual(resolve(40, 0, vx: 800), .right)
        XCTAssertEqual(resolve(0, -30, vy: -900), .up)
        XCTAssertNil(resolve(40, 0, vx: 600))
    }

    func testDominantAxisWins() {
        XCTAssertEqual(resolve(150, 140), .right)
        XCTAssertEqual(resolve(140, 150), .down)
        XCTAssertEqual(resolve(-60, -300), .up)
    }

    func testVelocityOnTheOtherAxisIsIgnored() {
        XCTAssertNil(resolve(50, 0, vx: 100, vy: 5000))
    }

    func testBadgeAppearsOutsideTheDeadZoneOnly() {
        XCTAssertNil(SwipeResolver.activeDirection(for: .zero))
        XCTAssertNil(SwipeResolver.activeDirection(for: CGSize(width: 15, height: 0)))
        XCTAssertEqual(SwipeResolver.activeDirection(for: CGSize(width: 40, height: 5)), .right)
        XCTAssertEqual(SwipeResolver.activeDirection(for: CGSize(width: -40, height: 5)), .left)
        XCTAssertEqual(SwipeResolver.activeDirection(for: CGSize(width: 5, height: -40)), .up)
        XCTAssertEqual(SwipeResolver.activeDirection(for: CGSize(width: 5, height: 40)), .down)
    }

    func testProgressReachesOneAtTheThreshold() {
        XCTAssertEqual(SwipeResolver.progress(for: .zero), 0)
        XCTAssertEqual(SwipeResolver.progress(for: CGSize(width: 65, height: 0)), 0.5, accuracy: 0.001)
        XCTAssertEqual(SwipeResolver.progress(for: CGSize(width: 0, height: -130)), 1, accuracy: 0.001)
        XCTAssertGreaterThan(SwipeResolver.progress(for: CGSize(width: 260, height: 0)), 1)
    }

    func testFlyOutGoesOffScreenInTheSwipeDirection() {
        let t = CGSize(width: 10, height: 20)
        XCTAssertEqual(SwipeResolver.flyOutOffset(for: .right, translation: t).width, 900)
        XCTAssertEqual(SwipeResolver.flyOutOffset(for: .left, translation: t).width, -900)
        XCTAssertEqual(SwipeResolver.flyOutOffset(for: .up, translation: t).height, -900)
        XCTAssertEqual(SwipeResolver.flyOutOffset(for: .down, translation: t).height, 900)
    }
}

final class ModelLabelTests: XCTestCase {
    func testEveryDirectionHasUniqueTitleSymbolAndIdentifier() {
        let all: [SwipeDirection] = [.left, .right, .up, .down]
        XCTAssertEqual(Set(all.map(\.actionTitle)).count, 4)
        XCTAssertEqual(Set(all.map(\.symbolName)).count, 4)
        XCTAssertEqual(Set(all.map(\.identifier)).count, 4)
        XCTAssertEqual(Set(all.map { "\($0.color)" }).count, 4)
    }

    func testSnoozeDurationsExposeLabelsAndSymbols() {
        XCTAssertEqual(SnoozeDuration.allCases.count, 4)
        XCTAssertEqual(Set(SnoozeDuration.allCases.map(\.label)).count, 4)
        XCTAssertEqual(Set(SnoozeDuration.allCases.map(\.symbolName)).count, 4)
        XCTAssertEqual(Set(SnoozeDuration.allCases.map(\.id)).count, 4)
    }

    func testCardEqualityIsByIdentifier() {
        var a = MockData.inbox()[0]
        let b = a
        a.subject = "changé"
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(MockData.inbox()[0], MockData.inbox()[1])
    }
}

final class ConfigTests: XCTestCase {
    func testPlaceholderMeansNotConfigured() {
        XCTAssertFalse(Config.isConfigured(clientID: "YOUR_CLIENT_ID.apps.googleusercontent.com"))
        XCTAssertFalse(Config.isConfigured(clientID: ""))
        XCTAssertTrue(Config.isConfigured(clientID: "123-abc.apps.googleusercontent.com"))
        XCTAssertFalse(Config.isGmailConfigured, "le dépôt ne doit jamais contenir un vrai Client ID par défaut")
    }

    func testReversedSchemeIsDerivedFromTheClientIDPrefix() {
        XCTAssertEqual(Config.reversedScheme(forClientID: "123456-abcxyz.apps.googleusercontent.com"), "com.googleusercontent.apps.123456-abcxyz")
        XCTAssertEqual(Config.reversedScheme(forClientID: ""), "mailswipe.oauth")
        XCTAssertEqual(Config.reversedScheme(forClientID: "..."), "mailswipe.oauth")
    }

    func testRedirectURIUsesTheReversedScheme() {
        XCTAssertEqual(Config.redirectURI, "\(Config.reversedClientIDScheme):/oauth2redirect")
    }

    func testScopesAreTheMinimumNeeded() {
        let scopes = Set(Config.scopes.split(separator: " ").map(String.init))
        XCTAssertEqual(scopes, [
            "https://www.googleapis.com/auth/gmail.modify",
            "https://www.googleapis.com/auth/gmail.send",
            "https://www.googleapis.com/auth/userinfo.email",
        ])
        XCTAssertFalse(scopes.contains("https://mail.google.com/"), "pas d'accès complet qui permettrait la suppression définitive")
    }
}

final class MockDataTests: XCTestCase {
    func testBothLanguagesHaveTheSameTwelveMailsWithStableIDs() {
        let fr = MockData.inbox(french: true), en = MockData.inbox(french: false)
        XCTAssertEqual(fr.map(\.id), en.map(\.id))
        XCTAssertEqual(fr.count, 12)
        XCTAssertEqual(Set(fr.map(\.id)).count, 12)
        XCTAssertNotEqual(fr[0].subject, en[0].subject)
    }

    func testEveryMailHasContentAndAValidSender() {
        for french in [true, false] {
            for card in MockData.inbox(french: french) {
                XCTAssertFalse(card.subject.isEmpty); XCTAssertFalse(card.snippet.isEmpty)
                XCTAssertTrue(card.senderEmail.contains("@"), card.senderEmail)
            }
        }
    }

    func testBodiesExistForEveryMailInBothLanguages() {
        for french in [true, false] {
            for card in MockData.inbox(french: french) {
                XCTAssertGreaterThan(MockData.body(for: card.id, french: french).count, card.snippet.count - 1)
            }
        }
        XCTAssertTrue(MockData.body(for: "mock-2", french: true).contains("Horizon"))
        XCTAssertTrue(MockData.body(for: "mock-2", french: false).contains("Horizon"))
        XCTAssertTrue(MockData.body(for: "mock-9", french: false).contains("Bernard Studio"))
        XCTAssertTrue(MockData.body(for: "mock-9", french: true).contains("Atelier Bernard"))
    }

    func testUnknownIDStillReturnsASafeBody() {
        XCTAssertFalse(MockData.body(for: "nope", french: true).isEmpty)
    }

    func testMockServicePagesThroughEverything() async throws {
        let service = MockMailService(pageSize: 5)
        var token: String?
        var all: [EmailCard] = []
        repeat {
            let page = try await service.fetchInbox(pageToken: token)
            all += page.cards
            token = page.nextPageToken
        } while token != nil
        XCTAssertEqual(all.count, 12)
        let body = try await service.fetchBody(messageId: "mock-1")
        XCTAssertFalse(body.isEmpty)
        try await service.trash(messageId: "x"); try await service.archive(messageId: "x")
        try await service.snooze(messageId: "x"); try await service.unsnooze(messageId: "x")
        try await service.sendReply(to: all[0], body: "ok")
    }

    func testPageTokenBeyondTheEndYieldsAnEmptyLastPage() async throws {
        let page = try await MockMailService().fetchInbox(pageToken: "999")
        XCTAssertTrue(page.cards.isEmpty)
        XCTAssertNil(page.nextPageToken)
    }
}

final class GmailWriteCallTests: XCTestCase {
    override func setUp() { StubURLProtocol.reset() }

    private func api() -> GmailAPI { GmailAPI(auth: FakeTokenProvider(), session: StubURLProtocol.session()) }

    func testTrashPostsToTheTrashEndpoint() async throws {
        try await api().trash(messageId: "m42")
        let call = StubURLProtocol.recorded[0]
        XCTAssertEqual(call.method, "POST")
        XCTAssertTrue(call.url.path.hasSuffix("/messages/m42/trash"))
    }

    func testArchiveRemovesOnlyTheInboxLabel() async throws {
        try await api().archive(messageId: "m42")
        let body = try XCTUnwrap(try JSONSerialization.jsonObject(with: StubURLProtocol.recorded[0].body ?? Data()) as? [String: [String]])
        XCTAssertEqual(body["removeLabelIds"], ["INBOX"])
        XCTAssertEqual(body["addLabelIds"], [])
    }

    func testSendReplyPostsRawMessageInTheOriginalThread() async throws {
        var card = MockData.inbox(french: true)[1]
        card.messageIdHeader = "<m@x>"
        try await api().sendReply(to: card, body: "Bonjour")
        let call = StubURLProtocol.recorded[0]
        XCTAssertTrue(call.url.path.hasSuffix("/messages/send"))
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: call.body ?? Data()) as? [String: String])
        XCTAssertEqual(json["threadId"], card.threadId)
        XCTAssertFalse(json["raw"]?.isEmpty ?? true)
        XCTAssertFalse(json["raw"]?.contains(where: { "+/=".contains($0) }) ?? true, "raw doit être en base64url")
    }

    func testSendReplyToANoReplyAddressFailsBeforeAnyNetworkCall() async {
        var card = MockData.inbox(french: true)[0]
        card.senderEmail = "pas-une-adresse"
        do { try await api().sendReply(to: card, body: "x"); XCTFail() } catch {
            XCTAssertTrue(error is ReplyError)
        }
        XCTAssertTrue(StubURLProtocol.recorded.isEmpty)
    }

    func testEmptyInboxReturnsAnEmptyPage() async throws {
        StubURLProtocol.handler = { _ in (200, Data(#"{"resultSizeEstimate":0}"#.utf8)) }
        let page = try await api().fetchInbox(pageToken: nil)
        XCTAssertTrue(page.cards.isEmpty)
        XCTAssertNil(page.nextPageToken)
    }

    func testSenderWithoutDisplayNameFallsBackToTheAddress() async throws {
        StubURLProtocol.handler = { request in
            request.url!.path.hasSuffix("/messages")
                ? (200, Data(#"{"messages":[{"id":"a"}]}"#.utf8))
                : (200, Data(#"{"id":"a","threadId":"t","payload":{"headers":[{"name":"From","value":"<solo@x.fr>"},{"name":"Date","value":"garbage"}]}}"#.utf8))
        }
        let card = try await api().fetchInbox(pageToken: nil).cards[0]
        XCTAssertEqual(card.senderName, "solo@x.fr")
        XCTAssertEqual(card.senderEmail, "solo@x.fr")
        XCTAssertEqual(card.subject, String(localized: "(sans objet)"))
        XCTAssertEqual(card.snippet, "")
    }

    func testQuotedDisplayNameIsUnquoted() async throws {
        StubURLProtocol.handler = { request in
            request.url!.path.hasSuffix("/messages")
                ? (200, Data(#"{"messages":[{"id":"a"}]}"#.utf8))
                : (200, Data(#"{"id":"a","threadId":"t","payload":{"headers":[{"name":"From","value":"\"Dupont, Camille\" <c@x.fr>"}]}}"#.utf8))
        }
        let card = try await api().fetchInbox(pageToken: nil).cards[0]
        XCTAssertEqual(card.senderName, "Dupont, Camille")
    }

    func testPlainAddressWithoutBracketsIsKeptAsIs() async throws {
        StubURLProtocol.handler = { request in
            request.url!.path.hasSuffix("/messages")
                ? (200, Data(#"{"messages":[{"id":"a"}]}"#.utf8))
                : (200, Data(#"{"id":"a","threadId":"t","payload":{"headers":[{"name":"From","value":"nobody@x.fr"}]}}"#.utf8))
        }
        let card = try await api().fetchInbox(pageToken: nil).cards[0]
        XCTAssertEqual(card.senderEmail, "nobody@x.fr")
    }
}
