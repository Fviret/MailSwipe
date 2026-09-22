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
                    } else if auth.isSignedIn {
                        Button("Se déconnecter de Gmail", role: .destructive) {
                            auth.signOut()
                        }
                    } else {
                        Button("Se connecter à Gmail") {
                            auth.signIn()
                        }
                    }
                }

                Section("À propos") {
                    LabeledContent("Gestes", value: "Glisse la carte dans une direction")
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
