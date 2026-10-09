import Foundation
import Combine

@MainActor
final class EmailStore: ObservableObject {
    @Published var inbox: [EmailCard] = []
    @Published var archived: [EmailCard] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastAction: LastAction?
    @Published private(set) var hasMore = false
    @Published private(set) var isLoadingMore = false
    @Published private var forcedMockPreview = false

    let auth: AuthManager
    let snoozeScheduler: SnoozeScheduler
    private let gmailService: MailService
    private let mockService: MailService
    private var dueCheckTimer: Timer?
    private var hasLoadedOnce = false
    private var nextPageToken: String?
    private var loadGeneration = 0
    /// Mails déjà traités pendant cette session : Gmail peut encore les renvoyer quelques secondes.
    private var handledIds = Set<String>()
    static let prefetchThreshold = 5

    var isMockMode: Bool { !Config.isGmailConfigured || forcedMockPreview }

    private var service: MailService { isMockMode ? mockService : gmailService }

    func enableMockPreview() {
        forcedMockPreview = true
    }

    struct LastAction: Identifiable {
        let id = UUID()
        let card: EmailCard
        let direction: SwipeDirection
    }

    init(
        auth: AuthManager,
        gmail: MailService? = nil,
        mock: MailService = MockMailService(),
        snoozeScheduler: SnoozeScheduler? = nil
    ) {
        self.auth = auth
        self.gmailService = gmail ?? GmailAPI(auth: auth)
        self.mockService = mock
        self.snoozeScheduler = snoozeScheduler ?? SnoozeScheduler()
        startDueCheckTimer()
    }

    /// Charge la boîte de réception. `force: true` (pull-to-refresh) recharge
    /// depuis la source ; sinon, un rechargement déjà effectué est ignoré pour
    /// ne pas écraser les swipes en cours quand la vue Inbox réapparaît
    /// (ex. changement d'onglet).
    func loadInbox(force: Bool = false) async {
        guard force || !hasLoadedOnce else { return }
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        errorMessage = nil
        nextPageToken = nil
        hasMore = false
        defer { if generation == loadGeneration { isLoading = false; hasLoadedOnce = true } }

        guard isMockMode || auth.isSignedIn else { return }
        do {
            let page = try await service.fetchInbox(pageToken: nil)
            guard generation == loadGeneration else { return }
            handledIds.removeAll()
            inbox = page.cards
            apply(page)
        } catch {
            guard generation == loadGeneration else { return }
            errorMessage = "Impossible de charger la boîte de réception : \(error.localizedDescription)"
        }
    }

    /// Charge la page suivante quand il reste peu de cartes à traiter.
    func loadMoreIfNeeded() async {
        guard hasMore, !isLoadingMore, !isLoading, inbox.count <= Self.prefetchThreshold,
              let token = nextPageToken else { return }
        let generation = loadGeneration
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await service.fetchInbox(pageToken: token)
            guard generation == loadGeneration else { return }
            let known = Set(inbox.map(\.id)).union(archived.map(\.id)).union(handledIds)
                .union(snoozeScheduler.items.map(\.id))
            inbox.append(contentsOf: page.cards.filter { !known.contains($0.id) })
            apply(page)
        } catch {
            errorMessage = "Impossible de charger plus de mails : \(error.localizedDescription)"
        }
    }

    private func apply(_ page: MailPage) {
        nextPageToken = page.nextPageToken
        hasMore = page.nextPageToken != nil
        if page.failedCount > 0 {
            errorMessage = "\(page.failedCount) mail(s) n'ont pas pu être chargés. Tire pour actualiser."
        }
    }

    // MARK: - Actions déclenchées par le swipe
    //
    // Chaque action est optimiste (la carte disparaît tout de suite) mais revient
    // à sa place d'origine si l'appel au serveur échoue, avec un message d'erreur.

    @discardableResult
    func reply(_ card: EmailCard, text: String) -> Task<Void, Never> {
        let index = detach(card)
        lastAction = LastAction(card: card, direction: .right)
        let service = self.service
        return Task {
            do { try await service.sendReply(to: card, body: text) }
            catch { rollback(card, at: index, message: "Échec de l'envoi", error: error) }
        }
    }

    @discardableResult
    func delete(_ card: EmailCard) -> Task<Void, Never> {
        let index = detach(card)
        lastAction = LastAction(card: card, direction: .left)
        let service = self.service
        return Task {
            do { try await service.trash(messageId: card.id) }
            catch { rollback(card, at: index, message: "Échec de la suppression", error: error) }
        }
    }

    @discardableResult
    func archive(_ card: EmailCard) -> Task<Void, Never> {
        let index = detach(card)
        archived.insert(card, at: 0)
        lastAction = LastAction(card: card, direction: .up)
        let service = self.service
        return Task {
            do { try await service.archive(messageId: card.id) }
            catch {
                archived.removeAll { $0.id == card.id }
                rollback(card, at: index, message: "Échec de l'archivage", error: error)
            }
        }
    }

    @discardableResult
    func snooze(_ card: EmailCard, duration: SnoozeDuration) -> Task<Void, Never> {
        let index = detach(card)
        snoozeScheduler.snooze(card, until: duration.resolvedDate())
        lastAction = LastAction(card: card, direction: .down)
        let service = self.service
        return Task {
            do { try await service.snooze(messageId: card.id) }
            catch {
                snoozeScheduler.remove(id: card.id)
                rollback(card, at: index, message: "Échec du snooze", error: error)
            }
        }
    }

    /// Retire la carte de la pile et renvoie sa position, pour pouvoir la remettre en cas d'échec.
    private func detach(_ card: EmailCard) -> Int {
        errorMessage = nil
        let index = inbox.firstIndex { $0.id == card.id } ?? 0
        inbox.removeAll { $0.id == card.id }
        handledIds.insert(card.id)
        return index
    }

    private func rollback(_ card: EmailCard, at index: Int, message: String, error: Error) {
        handledIds.remove(card.id)
        if !inbox.contains(where: { $0.id == card.id }) {
            inbox.insert(card, at: min(index, inbox.count))
        }
        errorMessage = "\(message) : \(error.localizedDescription)"
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
        let service = self.service
        for item in due {
            Task {
                do { try await service.unsnooze(messageId: item.id) }
                catch { errorMessage = "Impossible de remettre « \(item.card.subject) » dans ta boîte Gmail : \(error.localizedDescription)" }
            }
        }
    }
}
