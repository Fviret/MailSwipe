import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var store: EmailStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Compte") {
                    if let email = auth.userEmail {
                        LabeledContent("Connecté", value: email)
                    }
                    if store.isMockMode {
                        Label("Mode démo actif", systemImage: "wand.and.stars")
                            .foregroundStyle(.orange)
                        if Config.isGmailConfigured {
                            Button("Quitter le mode démo") { store.exitMockPreview() }
                        }
                    } else if auth.isSignedIn {
                        Button("Se déconnecter de Gmail", role: .destructive) {
                            auth.signOut()
                            store.clearLocalData()
                        }
                    } else {
                        Button("Se connecter à Gmail") {
                            auth.signIn()
                        }
                    }
                }

                Section("Confidentialité et assistance") {
                    Link(destination: Config.privacyPolicyURL) {
                        Label("Politique de confidentialité", systemImage: "hand.raised")
                    }
                    Link(destination: Config.supportURL) {
                        Label("Assistance", systemImage: "questionmark.circle")
                    }
                    Text("Tes mails ne transitent que entre ton iPhone et Google. Aucun serveur MailSwipe, aucun suivi.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("À propos") {
                    LabeledContent("Gestes", value: String(localized: "Glisse la carte dans une direction"))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("→ Droite : Répondre")
                        Text("← Gauche : Supprimer")
                        Text("↑ Haut : Archiver")
                        Text("↓ Bas : Snoozer (fonctionnalité innovante)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Réglages")
        }
    }
}
