import Foundation
import AuthenticationServices
import CryptoKit
import UIKit

/// Ce dont l'API Gmail a besoin d'une session : un jeton valide, et de quoi réagir à un refus.
protocol AccessTokenProviding: AnyObject {
    func validAccessToken() async throws -> String
    func invalidateAccessToken() async
    func handleSessionExpired() async
}

@MainActor
final class AuthManager: NSObject, ObservableObject, AccessTokenProviding {
    @Published var isSignedIn = false
    @Published var userEmail: String?
    @Published var lastError: String?

    private var accessToken: String?
    private var accessTokenExpiry: Date?
    private var codeVerifier: String?
    private var pendingState: String?
    private var webAuthSession: ASWebAuthenticationSession?

    private let session: URLSession
    private let refreshTokenKey: String

    init(session: URLSession = .shared, refreshTokenKey: String = "gmail_refresh_token") {
        self.session = session
        self.refreshTokenKey = refreshTokenKey
        super.init()
        if KeychainStore.get(refreshTokenKey) != nil {
            isSignedIn = true
        }
    }

    // MARK: - Sign in

    func signIn() {
        guard Config.isGmailConfigured else {
            lastError = String(localized: "Configure d'abord ton Client ID Google dans Config.swift.")
            return
        }

        guard let authURL = beginAuthorization() else { return }

        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: Config.reversedClientIDScheme
        ) { [weak self] callbackURL, error in
            guard let self else { return }
            Task { @MainActor in await self.completeAuthorization(callbackURL: callbackURL, error: error) }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        webAuthSession = session
        session.start()
    }

    /// Prépare une connexion : mémorise verifier PKCE et `state`, et renvoie l'URL d'autorisation Google.
    func beginAuthorization() -> URL? {
        let verifier = Self.randomURLSafeString(length: 64)
        codeVerifier = verifier
        let challenge = Self.codeChallenge(for: verifier)
        let state = Self.randomURLSafeString(length: 16)
        pendingState = state

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Config.googleOAuthClientID),
            URLQueryItem(name: "redirect_uri", value: Config.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Config.scopes),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "access_type", value: "offline"),
        ]
        return components.url
    }

    /// Traite la redirection de Google : annulation, erreur, `state` invalide, ou échange du code contre des jetons.
    func completeAuthorization(callbackURL: URL?, error: Error?) async {
        if let error {
            if (error as NSError).code != ASWebAuthenticationSessionError.canceledLogin.rawValue {
                lastError = error.localizedDescription
            }
            return
        }
        defer { pendingState = nil }
        guard let callbackURL, let expectedState = pendingState else {
            lastError = AuthFlowError.missingCode.localizedDescription
            return
        }
        do {
            let code = try Self.authorizationCode(from: callbackURL, expectedState: expectedState)
            await exchangeCodeForTokens(code: code)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Valide la redirection OAuth : refuse un `state` différent (CSRF) et remonte les erreurs Google.
    nonisolated static func authorizationCode(from callback: URL, expectedState: String) throws -> String {
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }

        if let error = value("error") {
            throw AuthFlowError.denied(error)
        }
        guard value("state") == expectedState else {
            throw AuthFlowError.stateMismatch
        }
        guard let code = value("code"), !code.isEmpty else {
            throw AuthFlowError.missingCode
        }
        return code
    }

    func invalidateAccessToken() {
        accessToken = nil
        accessTokenExpiry = nil
    }

    /// Jeton révoqué ou expiré : on déconnecte proprement et on explique pourquoi.
    func handleSessionExpired() {
        signOut()
        lastError = GmailError.sessionExpired.localizedDescription
    }

    func signOut() {
        KeychainStore.remove(refreshTokenKey)
        accessToken = nil
        accessTokenExpiry = nil
        isSignedIn = false
        userEmail = nil
    }

    // MARK: - Token exchange

    private func exchangeCodeForTokens(code: String) async {
        guard let verifier = codeVerifier else { return }
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "client_id": Config.googleOAuthClientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": Config.redirectURI,
        ]
        request.httpBody = Self.formEncode(params)

        do {
            let (data, response) = try await session.data(for: request)
            try Self.validate(response, data: data)
            let token = try JSONDecoder().decode(TokenResponse.self, from: data)
            accessToken = token.accessToken
            accessTokenExpiry = Date().addingTimeInterval(TimeInterval(token.expiresIn))
            if let refresh = token.refreshToken {
                KeychainStore.set(refresh, for: refreshTokenKey)
            }
            isSignedIn = true
            await fetchUserEmail()
        } catch {
            lastError = String(localized: "Échec de connexion Gmail : \(error.localizedDescription)")
        }
    }

    /// Retourne un access token valide, en le rafraîchissant si besoin.
    func validAccessToken() async throws -> String {
        if let token = accessToken, let expiry = accessTokenExpiry, expiry > Date().addingTimeInterval(60) {
            return token
        }
        guard let refreshToken = KeychainStore.get(refreshTokenKey) else {
            throw GmailError.notSignedIn
        }

        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let params = [
            "client_id": Config.googleOAuthClientID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token",
        ]
        request.httpBody = Self.formEncode(params)

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 400 || http.statusCode == 401,
           String(data: data, encoding: .utf8)?.contains("invalid_grant") == true {
            handleSessionExpired()
            throw GmailError.sessionExpired
        }
        try Self.validate(response, data: data)
        let token = try JSONDecoder().decode(TokenResponse.self, from: data)
        accessToken = token.accessToken
        accessTokenExpiry = Date().addingTimeInterval(TimeInterval(token.expiresIn))
        return token.accessToken
    }

    private func fetchUserEmail() async {
        guard let token = try? await validAccessToken() else { return }
        var request = URLRequest(url: URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await session.data(for: request) else { return }
        struct UserInfo: Decodable { let email: String? }
        userEmail = try? JSONDecoder().decode(UserInfo.self, from: data).email
    }

    // MARK: - Helpers

    private static func randomURLSafeString(length: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func codeChallenge(for verifier: String) -> String {
        let hashed = SHA256.hash(data: Data(verifier.utf8))
        return Data(hashed).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func formEncode(_ params: [String: String]) -> Data {
        params.map { key, value in
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(key)=\(encodedValue)"
        }
        .joined(separator: "&")
        .data(using: .utf8) ?? Data()
    }

    private static func validate(_ response: URLResponse, data: Data) throws {
        try GmailError.validate(response, data: data)
    }
}

extension AuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene {
                for window in windowScene.windows where window.isKeyWindow {
                    return window
                }
            }
        }
        return ASPresentationAnchor()
    }
}

private struct TokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}

enum AuthFlowError: LocalizedError, Equatable {
    case stateMismatch
    case missingCode
    case denied(String)

    var errorDescription: String? {
        switch self {
        case .stateMismatch: return String(localized: "La réponse de Google ne correspond pas à ta demande de connexion. Réessaie.")
        case .missingCode: return String(localized: "Autorisation Google incomplète.")
        case .denied(let reason): return String(localized: "Google a refusé la connexion (\(reason)).")
        }
    }
}

enum GmailError: LocalizedError, Equatable {
    case notSignedIn
    case sessionExpired
    case api(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return String(localized: "Non connecté à Gmail.")
        case .sessionExpired:
            return String(localized: "Ta session Gmail a expiré. Reconnecte-toi pour continuer.")
        case .api(let status, let message):
            return message.isEmpty ? String(localized: "Gmail a répondu avec une erreur (\(status)).") : message
        }
    }

    /// Transforme une réponse HTTP non-2xx en erreur lisible (message Google extrait du JSON).
    static func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw GmailError.api(status: 0, message: "") }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 { throw GmailError.sessionExpired }
            throw GmailError.api(status: http.statusCode, message: googleMessage(from: data))
        }
    }

    private static func googleMessage(from data: Data) -> String {
        struct Envelope: Decodable {
            struct Body: Decodable { let message: String? }
            let error: Body?
        }
        return (try? JSONDecoder().decode(Envelope.self, from: data))?.error?.message ?? ""
    }
}
