import Foundation

/// Réglages de lancement utilisés uniquement par les tests d'interface (arguments `-ui-*`).
enum LaunchOptions {
    static let arguments = ProcessInfo.processInfo.arguments

    /// Données isolées et jetables, aucune notification, délai d'annulation court.
    static var isUITesting: Bool { arguments.contains("-ui-testing") }

    /// Durée de la fenêtre d'annulation en test d'interface (`-ui-undo-delay 8`), 4 s par défaut comme en production.
    static var undoDelay: TimeInterval {
        guard let index = arguments.firstIndex(of: "-ui-undo-delay"), arguments.indices.contains(index + 1),
              let seconds = TimeInterval(arguments[index + 1]) else { return 4 }
        return seconds
    }

    /// Fait comme si un Client ID Google était configuré (affiche l'écran de connexion).
    static var simulatesGmailConfigured: Bool { arguments.contains("-ui-gmail-configured") }
}
