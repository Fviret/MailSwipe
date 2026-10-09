import Foundation
import Combine

@MainActor
final class EmailStore: ObservableObject {
    @Published var inbox: [EmailCard] = []
    @Published var archived: [EmailCard] = [] {
        didSet { archiveStorage.save(Array(archived.prefix(Self.archiveLimit))) }
    }
    @Published var isLoading = false
    @Published var errorMessage: String?
    /// Action en attente : elle n'est envoyée au serveur qu'après `undoDelay`, sauf si on l'annule.
    @Published private(set) var pending: PendingAction?
    @Published private(set) var hasMore = false
    @Published private(set) var isLoadingMore = false
    @Published private var forcedMockPreview = false

    let auth: AuthManager
    let snoozeScheduler: SnoozeScheduler
    private let gmailService: MailService
    private let mockService: MailService
    private var archiveStorage: JSONFileStore<[EmailCard]>
    private let storageRoot: URL
    private let gmailConfigured: Bool
    static let archiveLimit = 200
    private var dueCheckTimer: Timer?
    private var hasLoadedOnce = false
    private var cancellables = Set<AnyCancellable>()
    private var nextPageToken: String?
    private var loadGeneration = 0
    private var bodyCache: [String: String] = [:]
    /// Mails déjà traités pendant cette session : Gmail peut encore les renvoyer quelques secondes.
    private var handledIds = Set<String>()
    static let prefetchThreshold = 5

    var isMockMode: Bool { !gmailConfigured || forcedMockPreview }

    private var service: MailService { isMockMode ? mockService : gmailService }

    /// Démo : mails fictifs, sans réseau ni compte. Les données locales sont isolées du compte réel.
    func enableMockPreview() {
        forcedMockPreview = true
        resetSession()
    }

    func exitMockPreview() {
        forcedMockPreview = false
        resetSession()
    }

    private func resetSession() {
        pending?.task?.cancel()
        pending = nil
        inbox = []
        hasMore = false
        nextPageToken = nil
        hasLoadedOnce = false
        errorMessage = nil
        handledIds.removeAll()
        bodyCache = [:]
        let directory = storageDirectory()
        archiveStorage = JSONFileStore(filename: "archive.json", directory: directory)
        archived = archiveStorage.load() ?? []
        snoozeScheduler.use(directory: directory)
    }

    private func storageDirectory() -> URL {
        storageRoot.appendingPathComponent(isMockMode ? "demo" : "live", isDirectory: true)
    }

    let undoDelay: TimeInterval

    init(
        auth: AuthManager,
        gmail: MailService? = nil,
        mock: MailService = MockMailService(),
        snoozeScheduler: SnoozeScheduler? = nil,
        undoDelay: TimeInterval = 4,
        storageDirectory: URL? = nil,
        gmailConfigured: Bool = Config.isGmailConfigured,
        notifications: NotificationScheduling = SystemNotificationScheduler()
    ) {
        self.undoDelay = undoDelay
        self.auth = auth
        self.gmailService = gmail ?? GmailAPI(auth: auth)
        self.mockService = mock
        self.gmailConfigured = gmailConfigured
        self.storageRoot = storageDirectory ?? JSONFileStore<Int>.defaultDirectory
        // Démo et compte réel ne partagent jamais leurs données locales.
        let directory = self.storageRoot.appendingPathComponent(
            (!gmailConfigured) ? "demo" : "live", isDirectory: true
        )
        self.snoozeScheduler = snoozeScheduler ?? SnoozeScheduler(directory: directory, notifications: notifications)
        self.archiveStorage = JSONFileStore(filename: "archive.json", directory: directory)
        self.archived = archiveStorage.load() ?? []
        // Les vues lisent `store.snoozeScheduler.items` : sans ce relais elles ne se rafraîchissent jamais.
        self.snoozeScheduler.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
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
            resurfaceDueSnoozes()
        } catch {
            guard generation == loadGeneration else { return }
            errorMessage = String(localized: "Impossible de charger la boîte de réception : \(error.localizedDescription)")
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
            errorMessage = String(localized: "Impossible de charger plus de mails : \(error.localizedDescription)")
        }
    }

    private func apply(_ page: MailPage) {
        nextPageToken = page.nextPageToken
        hasMore = page.nextPageToken != nil
        if page.failedCount > 0 {
            errorMessage = String(localized: "\(page.failedCount) mail(s) n'ont pas pu être chargés. Appuie sur Actualiser pour réessayer.")
        }
    }

    // MARK: - Actions déclenchées par le swipe
    //
    // La carte disparaît tout de suite, mais l'action n'est envoyée qu'après `undoDelay`
    // (fenêtre d'annulation, comme « Annuler l'envoi » dans Gmail). Si l'appel serveur
    // échoue, la carte revient à sa place avec un message d'erreur.

    @discardableResult
    func reply(_ card: EmailCard, text: String) -> Task<Void, Never> {
        begin(card, .reply(text))
    }

    @discardableResult
    func delete(_ card: EmailCard) -> Task<Void, Never> {
        begin(card, .delete)
    }

    @discardableResult
    func archive(_ card: EmailCard) -> Task<Void, Never> {
        begin(card, .archive)
    }

    @discardableResult
    func snooze(_ card: EmailCard, duration: SnoozeDuration) -> Task<Void, Never> {
        begin(card, .snooze(until: duration.resolvedDate()))
    }

    /// Annule l'action en cours : la carte revient à sa place, rien n'est envoyé.
    func undo() {
        guard let action = pending, !action.isResolved else { return }
        action.isResolved = true
        action.task?.cancel()
        pending = nil
        handledIds.remove(action.card.id)
        reinsert(action.card, at: action.index)
    }

    /// Valide tout de suite l'action en attente (nouvelle action, app qui passe en arrière-plan…).
    func flushPending() async {
        guard let action = pending else { return }
        action.task?.cancel()
        await commit(action)
    }

    private func begin(_ card: EmailCard, _ kind: PendingAction.Kind) -> Task<Void, Never> {
        if let previous = pending {
            previous.task?.cancel()
            Task { await commit(previous) }
        }
        errorMessage = nil
        let index = inbox.firstIndex { $0.id == card.id } ?? 0
        inbox.removeAll { $0.id == card.id }
        handledIds.insert(card.id)

        let action = PendingAction(card: card, kind: kind, index: index, delay: undoDelay)
        pending = action
        let delay = undoDelay
        action.task = Task {
            if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            guard !Task.isCancelled else { return }
            await commit(action)
        }
        return action.task!
    }

    private func commit(_ action: PendingAction) async {
        guard !action.isResolved else { return }
        action.isResolved = true
        if pending === action { pending = nil }
        let card = action.card
        let service = self.service
        switch action.kind {
        case .reply(let text):
            do { try await service.sendReply(to: card, body: text) }
            catch { rollback(action, message: String(localized: "Échec de l'envoi : \(error.localizedDescription)")) }
        case .delete:
            do { try await service.trash(messageId: card.id) }
            catch { rollback(action, message: String(localized: "Échec de la suppression : \(error.localizedDescription)")) }
        case .archive:
            archived.insert(card, at: 0)
            do { try await service.archive(messageId: card.id) }
            catch {
                archived.removeAll { $0.id == card.id }
                rollback(action, message: String(localized: "Échec de l'archivage : \(error.localizedDescription)"))
            }
        case .snooze(let date):
            snoozeScheduler.snooze(card, until: date)
            do { try await service.snooze(messageId: card.id) }
            catch {
                snoozeScheduler.remove(id: card.id)
                rollback(action, message: String(localized: "Échec du snooze : \(error.localizedDescription)"))
            }
        }
    }

    private func rollback(_ action: PendingAction, message: String) {
        handledIds.remove(action.card.id)
        reinsert(action.card, at: action.index)
        errorMessage = message
    }

    private func reinsert(_ card: EmailCard, at index: Int) {
        if !inbox.contains(where: { $0.id == card.id }) {
            inbox.insert(card, at: min(index, inbox.count))
        }
    }

    /// Texte complet du mail (mis en cache pour la session).
    func body(for card: EmailCard) async throws -> String {
        if let cached = bodyCache[card.id] { return cached }
        let text = try await service.fetchBody(messageId: card.id)
        bodyCache[card.id] = text
        return text
    }

    /// Efface les données locales d'un compte (archive et mails snoozés), à la déconnexion.
    func clearLocalData() {
        pending?.task?.cancel()
        pending = nil
        archived = []
        bodyCache = [:]
        archiveStorage.delete()
        snoozeScheduler.removeAll()
        inbox = []
        hasLoadedOnce = false
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
            let card = item.card
            if !inbox.contains(where: { $0.id == card.id }) {
                inbox.insert(card, at: 0)
            }
        }
        let service = self.service
        for item in due {
            Task {
                do { try await service.unsnooze(messageId: item.id) }
                catch { errorMessage = String(localized: "Impossible de remettre « \(item.card.subject) » dans ta boîte Gmail : \(error.localizedDescription)") }
            }
        }
    }
}

@MainActor
final class PendingAction: Identifiable {
    enum Kind {
        case reply(String)
        case delete
        case archive
        case snooze(until: Date)
    }

    let id = UUID()
    let card: EmailCard
    let kind: Kind
    let index: Int
    let delay: TimeInterval
    var isResolved = false
    var task: Task<Void, Never>?

    init(card: EmailCard, kind: Kind, index: Int, delay: TimeInterval) {
        self.card = card
        self.kind = kind
        self.index = index
        self.delay = delay
    }

    var direction: SwipeDirection {
        switch kind {
        case .reply: return .right
        case .delete: return .left
        case .archive: return .up
        case .snooze: return .down
        }
    }
}
