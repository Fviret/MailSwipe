import XCTest
@testable import MailSwipe

@MainActor
final class AuthFlowTests: XCTestCase {
    private let key = "unit-test-refresh-token"

    override func setUp() async throws {
        StubURLProtocol.reset()
        KeychainStore.remove(key)
    }

    override func tearDown() async throws {
        KeychainStore.remove(key)
    }

    private func makeAuth() -> AuthManager {
        AuthManager(session: StubURLProtocol.session(), refreshTokenKey: key)
    }

    private func formBody(_ call: StubURLProtocol.Recorded) -> [String: String] {
        let text = String(data: call.body ?? Data(), encoding: .utf8) ?? ""
        return Dictionary(uniqueKeysWithValues: text.split(separator: "&").compactMap { pair -> (String, String)? in
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            return parts.count == 2 ? (parts[0], parts[1].removingPercentEncoding ?? parts[1]) : nil
        })
    }

    private func tokenJSON(access: String = "access-1", refresh: String? = "refresh-1", expiresIn: Int = 3600) -> Data {
        var json = #"{"access_token":"\#(access)","expires_in":\#(expiresIn)"#
        if let refresh { json += #","refresh_token":"\#(refresh)""# }
        return Data((json + "}").utf8)
    }

    // MARK: - État initial

    func testStartsSignedOutWithoutStoredToken() {
        XCTAssertFalse(makeAuth().isSignedIn)
    }

    func testStartsSignedInWhenARefreshTokenIsStored() {
        KeychainStore.set("stored", for: key)
        XCTAssertTrue(makeAuth().isSignedIn)
    }

    // MARK: - URL d'autorisation

    func testAuthorizationURLCarriesPKCEStateScopesAndRedirect() throws {
        let auth = makeAuth()
        let url = try XCTUnwrap(auth.beginAuthorization())
        let items = Dictionary(uniqueKeysWithValues: URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!.map { ($0.name, $0.value ?? "") })

        XCTAssertEqual(url.host, "accounts.google.com")
        XCTAssertEqual(items["response_type"], "code")
        XCTAssertEqual(items["code_challenge_method"], "S256")
        XCTAssertEqual(items["access_type"], "offline")
        XCTAssertEqual(items["redirect_uri"], Config.redirectURI)
        XCTAssertEqual(items["scope"], Config.scopes)
        XCTAssertEqual(items["client_id"], Config.googleOAuthClientID)
        XCTAssertGreaterThanOrEqual(items["state"]?.count ?? 0, 16)
        XCTAssertGreaterThanOrEqual(items["code_challenge"]?.count ?? 0, 43, "SHA-256 en base64url = 43 caractères")
        for value in [items["state"], items["code_challenge"]] {
            XCTAssertFalse(value?.contains(where: { "+/=".contains($0) }) ?? true, "base64url sans +, / ni =")
        }
    }

    func testEachAuthorizationUsesFreshStateAndChallenge() throws {
        let auth = makeAuth()
        func state(_ url: URL?) -> String { URLComponents(url: url!, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "state" }!.value! }
        XCTAssertNotEqual(state(auth.beginAuthorization()), state(auth.beginAuthorization()))
    }

    // MARK: - Redirection

    private func callback(state: String?, code: String? = "abc", error: String? = nil) -> URL {
        var items = [String]()
        if let code { items.append("code=\(code)") }
        if let state { items.append("state=\(state)") }
        if let error { items.append("error=\(error)") }
        return URL(string: "x.y:/oauth2redirect?\(items.joined(separator: "&"))")!
    }

    private func currentState(_ auth: AuthManager) -> String {
        URLComponents(url: auth.beginAuthorization()!, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "state" }!.value!
    }

    func testSuccessfulCallbackStoresTokensAndFetchesEmail() async {
        let auth = makeAuth()
        let state = currentState(auth)
        StubURLProtocol.handler = { request in
            request.url!.host == "oauth2.googleapis.com"
                ? (200, self.tokenJSON())
                : (200, Data(#"{"email":"flo@example.com"}"#.utf8))
        }
        await auth.completeAuthorization(callbackURL: callback(state: state), error: nil)

        XCTAssertTrue(auth.isSignedIn)
        XCTAssertEqual(auth.userEmail, "flo@example.com")
        XCTAssertNil(auth.lastError)
        XCTAssertEqual(KeychainStore.get(key), "refresh-1")

        let exchange = formBody(StubURLProtocol.recorded[0])
        XCTAssertEqual(exchange["grant_type"], "authorization_code")
        XCTAssertEqual(exchange["code"], "abc")
        XCTAssertEqual(exchange["redirect_uri"], Config.redirectURI)
        XCTAssertGreaterThanOrEqual(exchange["code_verifier"]?.count ?? 0, 43, "le verifier PKCE est envoyé")
        XCTAssertNil(exchange["client_secret"], "client public : jamais de secret")
        let userInfoRequest = StubURLProtocol.recorded.last!
        XCTAssertTrue(userInfoRequest.url.path.contains("userinfo"))
    }

    func testWrongStateIsRejectedAndNothingIsExchanged() async {
        let auth = makeAuth()
        _ = currentState(auth)
        await auth.completeAuthorization(callbackURL: callback(state: "evil"), error: nil)
        XCTAssertFalse(auth.isSignedIn)
        XCTAssertEqual(auth.lastError, AuthFlowError.stateMismatch.localizedDescription)
        XCTAssertTrue(StubURLProtocol.recorded.isEmpty, "aucun échange de code si le state est faux")
    }

    func testCallbackWithoutPendingAuthorizationIsRejected() async {
        let auth = makeAuth()
        await auth.completeAuthorization(callbackURL: callback(state: "x"), error: nil)
        XCTAssertEqual(auth.lastError, AuthFlowError.missingCode.localizedDescription)
        XCTAssertFalse(auth.isSignedIn)
    }

    func testStateCannotBeReplayed() async {
        let auth = makeAuth()
        let state = currentState(auth)
        StubURLProtocol.handler = { _ in (200, self.tokenJSON()) }
        await auth.completeAuthorization(callbackURL: callback(state: state), error: nil)
        StubURLProtocol.reset()
        auth.lastError = nil
        await auth.completeAuthorization(callbackURL: callback(state: state), error: nil)
        XCTAssertNotNil(auth.lastError, "un state déjà consommé ne doit plus être accepté")
        XCTAssertTrue(StubURLProtocol.recorded.isEmpty)
    }

    func testUserCancellationIsSilent() async {
        let auth = makeAuth()
        _ = currentState(auth)
        let cancelled = NSError(domain: "com.apple.AuthenticationServices.WebAuthenticationSession", code: 1)
        await auth.completeAuthorization(callbackURL: nil, error: cancelled)
        XCTAssertNil(auth.lastError)
        XCTAssertFalse(auth.isSignedIn)
    }

    func testOtherSessionErrorsAreShown() async {
        let auth = makeAuth()
        _ = currentState(auth)
        await auth.completeAuthorization(callbackURL: nil, error: NSError(domain: "x", code: 99, userInfo: [NSLocalizedDescriptionKey: "réseau coupé"]))
        XCTAssertEqual(auth.lastError, "réseau coupé")
    }

    func testGoogleDenialIsReported() async {
        let auth = makeAuth()
        let state = currentState(auth)
        await auth.completeAuthorization(callbackURL: callback(state: state, code: nil, error: "access_denied"), error: nil)
        XCTAssertEqual(auth.lastError, AuthFlowError.denied("access_denied").localizedDescription)
    }

    func testTokenEndpointFailureIsReportedAndLeavesUserSignedOut() async {
        let auth = makeAuth()
        let state = currentState(auth)
        StubURLProtocol.handler = { _ in (400, Data(#"{"error":{"message":"bad code"}}"#.utf8)) }
        await auth.completeAuthorization(callbackURL: callback(state: state), error: nil)
        XCTAssertFalse(auth.isSignedIn)
        XCTAssertTrue(auth.lastError?.contains("bad code") ?? false)
        XCTAssertNil(KeychainStore.get(key))
    }

    // MARK: - Jetons

    func testCachedAccessTokenIsReusedWithoutNetwork() async throws {
        let auth = makeAuth()
        let state = currentState(auth)
        StubURLProtocol.handler = { request in request.url!.host == "oauth2.googleapis.com" ? (200, self.tokenJSON(expiresIn: 3600)) : (200, Data("{}".utf8)) }
        await auth.completeAuthorization(callbackURL: callback(state: state), error: nil)
        StubURLProtocol.reset()

        let token = try await auth.validAccessToken()
        XCTAssertEqual(token, "access-1")
        XCTAssertTrue(StubURLProtocol.recorded.isEmpty)
    }

    func testExpiredAccessTokenIsRefreshedWithTheStoredRefreshToken() async throws {
        KeychainStore.set("refresh-9", for: key)
        let auth = makeAuth()
        StubURLProtocol.handler = { _ in (200, self.tokenJSON(access: "fresh", refresh: nil)) }

        let token = try await auth.validAccessToken()
        XCTAssertEqual(token, "fresh")
        let body = formBody(StubURLProtocol.recorded[0])
        XCTAssertEqual(body["grant_type"], "refresh_token")
        XCTAssertEqual(body["refresh_token"], "refresh-9")
    }

    func testInvalidatedTokenIsRefreshedAgain() async throws {
        KeychainStore.set("refresh-9", for: key)
        let auth = makeAuth()
        var count = 0
        StubURLProtocol.handler = { _ in count += 1; return (200, self.tokenJSON(access: "t\(count)", refresh: nil)) }
        _ = try await auth.validAccessToken()
        auth.invalidateAccessToken()
        let second = try await auth.validAccessToken()
        XCTAssertEqual(second, "t2")
    }

    func testMissingRefreshTokenThrowsNotSignedIn() async {
        let auth = makeAuth()
        do { _ = try await auth.validAccessToken(); XCTFail() } catch {
            XCTAssertEqual(error as? GmailError, .notSignedIn)
        }
    }

    func testRevokedRefreshTokenSignsOutWithExplanation() async {
        KeychainStore.set("revoked", for: key)
        let auth = makeAuth()
        XCTAssertTrue(auth.isSignedIn)
        StubURLProtocol.handler = { _ in (400, Data(#"{"error":"invalid_grant"}"#.utf8)) }
        do { _ = try await auth.validAccessToken(); XCTFail() } catch {
            XCTAssertEqual(error as? GmailError, .sessionExpired)
        }
        XCTAssertFalse(auth.isSignedIn)
        XCTAssertNil(KeychainStore.get(key))
        XCTAssertEqual(auth.lastError, GmailError.sessionExpired.localizedDescription)
    }

    func testOtherRefreshFailuresKeepTheSession() async {
        KeychainStore.set("ok", for: key)
        let auth = makeAuth()
        StubURLProtocol.handler = { _ in (503, Data()) }
        do { _ = try await auth.validAccessToken(); XCTFail() } catch {
            XCTAssertEqual(error as? GmailError, .api(status: 503, message: ""))
        }
        XCTAssertTrue(auth.isSignedIn, "une panne réseau ne doit pas déconnecter")
        XCTAssertEqual(KeychainStore.get(key), "ok")
    }

    func testSignOutClearsEverything() async {
        let auth = makeAuth()
        let state = currentState(auth)
        StubURLProtocol.handler = { request in request.url!.host == "oauth2.googleapis.com" ? (200, self.tokenJSON()) : (200, Data(#"{"email":"a@b.c"}"#.utf8)) }
        await auth.completeAuthorization(callbackURL: callback(state: state), error: nil)
        auth.signOut()
        XCTAssertFalse(auth.isSignedIn)
        XCTAssertNil(auth.userEmail)
        XCTAssertNil(KeychainStore.get(key))
    }

    func testSignInRefusesToStartWithoutClientID() {
        let auth = makeAuth()
        auth.signIn()
        XCTAssertEqual(auth.lastError, String(localized: "Configure d'abord ton Client ID Google dans Config.swift."))
    }
}
