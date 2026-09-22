import Foundation
import Combine

@MainActor
final class EmailStore: ObservableObject {
    @Published var inbox: [EmailCard] = []
    @Published var archived: [EmailCard] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastAction: LastAction?
    @Published private var forcedMockPreview = false

    let auth: AuthManager
    let snoozeScheduler = SnoozeScheduler()
    private var api: GmailAPI?
    private var dueCheckTimer: Timer?
    private var hasLoadedOnce = false

    var isMockMode: Bool { !Config.isGmailConfigured || forcedMockPreview }

    func enableMockPreview() {
        forcedMockPreview = true
    }

    struct LastAction: Identifiable {
        let id = UUID()
        let card: EmailCard
        let direction: SwipeDirection
    }

    init(auth: AuthManager) {
        self.auth = auth
        self.api = GmailAPI(auth: auth)
        startDueCheckTimer()
    }

    /// Charge la boîte de réception. `force: true` (pull-to-refresh) recharge
    /// depuis la source ; sinon, un rechargement déjà effectué est ignoré pour
    /// ne pas écraser les swipes en cours quand la vue Inbox réapparaît
    /// (ex. changement d'onglet).
    func loadInbox(force: Bool = false) async {
        guard force || !hasLoadedOnce else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false; hasLoadedOnce = true }

        if isMockMode {
            inbox = MockData.inbox()
            return
        }
        guard auth.isSignedIn, let api else { return }
        do {
            inbox = try await api.fetchInbox()
        } catch {
            errorMessage = "Impossible de charger la boîte de réception : \(error.localizedDescription)"
        }
    }

    // MARK: - Actions déclenchées par le swipe

    func reply(_ card: EmailCard, text: String) {
        remove(card)
        lastAction = LastAction(card: card, direction: .right)
        guard !isMockMode, let api else { return }
        Task {
            do { try await api.sendReply(to: card, body: text) }
            catch { errorMessage = "Échec de l'envoi : \(error.localizedDescription)" }
        }
    }

    func delete(_ card: EmailCard) {
        remove(card)
        lastAction = LastAction(card: card, direction: .left)
        guard !isMockMode, let api else { return }
        Task {
            do { try await api.trash(messageId: card.id) }
            catch { errorMessage = "Échec de la suppression : \(error.localizedDescription)" }
        }
    }

    func archive(_ card: EmailCard) {
        remove(card)
        archived.insert(card, at: 0)
        lastAction = LastAction(card: card, direction: .up)
        guard !isMockMode, let api else { return }
        Task {
            do { try await api.archive(messageId: card.id) }
            catch { errorMessage = "Échec de l'archivage : \(error.localizedDescription)" }
        }
    }

    func snooze(_ card: EmailCard, duration: SnoozeDuration) {
        remove(card)
        snoozeScheduler.snooze(card, until: duration.resolvedDate())
        lastAction = LastAction(card: card, direction: .down)
        guard !isMockMode, let api else { return }
        Task {
            do { try await api.snoozeAway(messageId: card.id) }
            catch { errorMessage = "Échec du snooze : \(error.localizedDescription)" }
        }
    }

    private func remove(_ card: EmailCard) {
        inbox.removeAll { $0.id == card.id }
    }

    // MARK: - Réapparition des mails snoozés

    private func startDueCheckTimer() {
        dueCheckTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.resurfaceDueSnoozes() }
        }
    }

    func resurfaceDueSnoozes() {
        let due = snoozeScheduler.popDueItems()
        guard !due.isEmpty else { return }
        for item in due {
            let card = item.card.asEmailCard(id: item.id)
            if !inbox.contains(where: { $0.id == card.id }) {
                inbox.insert(card, at: 0)
            }
        }
        guard !isMockMode, let api else { return }
        for item in due {
            Task { try? await api.unsnooze(messageId: item.id) }
        }
    }
}
