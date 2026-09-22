import Foundation
import AuthenticationServices
import CryptoKit
import UIKit

@MainActor
final class AuthManager: NSObject, ObservableObject {
    @Published var isSignedIn = false
    @Published var userEmail: String?
    @Published var lastError: String?

    private var accessToken: String?
    private var accessTokenExpiry: Date?
    private var codeVerifier: String?
    private var webAuthSession: ASWebAuthenticationSession?

    private let refreshTokenKey = "gmail_refresh_token"

    override init() {
        super.init()
        if KeychainStore.get(refreshTokenKey) != nil {
            isSignedIn = true
        }
    }

    // MARK: - Sign in

    func signIn() {
        guard Config.isGmailConfigured else {
            lastError = "Configure d'abord ton Client ID Google dans Config.swift."
            return
        }

        let verifier = Self.randomURLSafeString(length: 64)
        codeVerifier = verifier
        let challenge = Self.codeChallenge(for: verifier)
        let state = Self.randomURLSafeString(length: 16)

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

        guard let authURL = components.url else { return }

        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: Config.reversedClientIDScheme
        ) { [weak self] callbackURL, error in
            guard let self else { return }
            Task { @MainActor in
                if let error {
                    if (error as NSError).code != ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        self.lastError = error.localizedDescription
                    }
                    return
                }
                guard let callbackURL,
                      let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value
                else {
                    self.lastError = "Autorisation Google incomplète."
                    return
                }
                await self.exchangeCodeForTokens(code: code)
            }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        webAuthSession = session
        session.start()
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
            let (data, response) = try await URLSession.shared.data(for: request)
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
            lastError = "Échec de connexion Gmail : \(error.localizedDescription)"
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

        let (data, response) = try await URLSession.shared.data(for: request)
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
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return }
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
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GmailError.requestFailed(body)
        }
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

enum GmailError: LocalizedError {
    case notSignedIn
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Non connecté à Gmail."
        case .requestFailed(let body): return "Requête Gmail échouée : \(body)"
        }
    }
}
