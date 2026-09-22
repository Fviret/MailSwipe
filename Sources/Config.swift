import Foundation

/// Connexion à Gmail — configuration OAuth.
///
/// Pour activer le vrai Gmail (au lieu du mode démo avec des mails fictifs) :
/// 1. Va sur https://console.cloud.google.com/ → crée un projet.
/// 2. Active l'API "Gmail API" (menu "APIs & Services" → "Library").
/// 3. "APIs & Services" → "Credentials" → "Create Credentials" → "OAuth client ID".
///    Choisis le type "iOS", Bundle ID = com.floviret.mailswipe
/// 4. Google te donne un Client ID de la forme :
///    123456789-abcxyz.apps.googleusercontent.com
/// 5. Colle-le ci-dessous dans `googleOAuthClientID`.
/// 6. Ouvre `project.yml` à la racine et remplace la valeur de
///    `GOOGLE_REVERSED_CLIENT_ID_SCHEME` par `com.googleusercontent.apps.XXXXX`
///    (le préfixe de ton Client ID, avant le premier point), puis relance :
///      xcodegen generate
///    C'est ce schéma d'URL que Google utilise pour revenir dans l'app après connexion.
/// 7. Sur l'écran "OAuth consent screen", ajoute ton adresse Gmail comme
///    "Test user" tant que l'app n'est pas publiée (mode "Testing").
enum Config {
    /// Remplace cette valeur par ton Client ID OAuth iOS Google Cloud.
    static let googleOAuthClientID = "YOUR_CLIENT_ID.apps.googleusercontent.com"

    /// Dérivé automatiquement : "123456789-abcxyz" à partir du Client ID.
    static var reversedClientIDScheme: String {
        guard let prefix = googleOAuthClientID.split(separator: ".").first else {
            return "mailswipe.oauth"
        }
        return "com.googleusercontent.apps.\(prefix)"
    }

    static let redirectURI = "\(reversedClientIDScheme):/oauth2redirect"

    static let scopes = [
        "https://www.googleapis.com/auth/gmail.modify",
        "https://www.googleapis.com/auth/gmail.send",
        "https://www.googleapis.com/auth/userinfo.email",
    ].joined(separator: " ")

    /// Tant que le Client ID n'a pas été renseigné, l'app tourne en mode démo
    /// avec des mails fictifs — pratique pour tester le swipe sans compte Gmail.
    static var isGmailConfigured: Bool {
        googleOAuthClientID != "YOUR_CLIENT_ID.apps.googleusercontent.com" && !googleOAuthClientID.isEmpty
    }
}
