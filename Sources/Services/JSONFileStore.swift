import Foundation

/// Stockage local d'un document JSON : dans Application Support (pas de UserDefaults en clair),
/// protégé tant que l'appareil n'a pas été déverrouillé une fois, et exclu des sauvegardes.
struct JSONFileStore<Value: Codable> {
    let url: URL

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MailSwipe", isDirectory: true)
    }

    init(filename: String, directory: URL? = nil) {
        let fileManager = FileManager.default
        var base = directory ?? Self.defaultDirectory
        try? fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? base.setResourceValues(values)
        url = base.appendingPathComponent(filename)
    }

    func load() -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    func save(_ value: Value) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func delete() {
        try? FileManager.default.removeItem(at: url)
    }
}
