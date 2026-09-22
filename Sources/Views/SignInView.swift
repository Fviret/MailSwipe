import SwiftUI

struct SignInView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var store: EmailStore

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor.gradient)
            Text("MailSwipe")
                .font(.largeTitle.bold())
            Text("Gère tes mails Gmail d'un simple geste.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            if let error = auth.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                Button {
                    auth.signIn()
                } label: {
                    Label("Se connecter avec Gmail", systemImage: "envelope.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!Config.isGmailConfigured)

                Button("Essayer en mode démo") {
                    store.enableMockPreview()
                }
                .font(.footnote)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }
}
