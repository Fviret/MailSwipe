import XCTest
@testable import MailSwipe

final class LocalizationTests: XCTestCase {
    private var repoRoot: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent() }

    private func catalog() throws -> [String: Any] {
        let data = try Data(contentsOf: repoRoot.appendingPathComponent("Sources/Localizable.xcstrings"))
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func strings() throws -> [String: [String: Any]] {
        try XCTUnwrap(catalog()["strings"] as? [String: [String: Any]])
    }

    private func english(_ entry: [String: Any]) -> String? {
        (((entry["localizations"] as? [String: Any])?["en"] as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String
    }

    private func specifiers(_ s: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: "%(?:\\d+\\$)?(?:lld|@|d)")
        return regex.matches(in: s, range: NSRange(s.startIndex..., in: s)).map { String(s[Range($0.range, in: s)!]) }
    }

    func testSourceLanguageIsFrench() throws {
        XCTAssertEqual(try catalog()["sourceLanguage"] as? String, "fr")
    }

    func testEveryKeyHasANonEmptyEnglishTranslation() throws {
        for (key, entry) in try strings() {
            XCTAssertFalse((english(entry) ?? "").isEmpty, "traduction anglaise manquante : \(key)")
        }
    }

    /// Un %@ perdu ou ajouté dans la traduction ferait planter ou afficher n'importe quoi.
    func testFormatSpecifiersMatchBetweenFrenchAndEnglish() throws {
        for (key, entry) in try strings() where key.contains("%") {
            XCTAssertEqual(specifiers(key), specifiers(english(entry) ?? ""), "spécificateurs différents : \(key)")
        }
    }

    /// Toute chaîne littérale passée à une vue ou à String(localized:) doit exister dans le catalogue.
    func testEveryLiteralUsedInCodeIsInTheCatalog() throws {
        // %lld et %@ se valent ici : le test ne distingue pas un Int d'un String interpolé.
        func normalized(_ s: String) -> String { s.replacingOccurrences(of: "%lld", with: "%@") }
        let known = Set(try strings().keys.map(normalized))
        let pattern = try NSRegularExpression(pattern: #"(?:Text|Button|Label|Section|Link|ProgressView|navigationTitle|DisclosureGroup|LabeledContent|alert|accessibilityHint|String\(localized:)\(?\s*"((?:[^"\\]|\\.)+)""#)
        let interpolation = #"\\\((?:[^()]|\([^()]*\))*\)"#
        let files = FileManager.default.enumerator(at: repoRoot.appendingPathComponent("Sources"), includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" } ?? []
        var missing: [String] = []
        for file in files {
            let code = try String(contentsOf: file, encoding: .utf8)
            for match in pattern.matches(in: code, range: NSRange(code.startIndex..., in: code)) {
                let raw = String(code[Range(match.range(at: 1), in: code)!])
                if raw.contains("String(localized") || raw.isEmpty { continue } // chaîne imbriquée : vérifiée à part
                let key = normalized(raw.replacingOccurrences(of: interpolation, with: "%@", options: .regularExpression))
                if !known.contains(key) { missing.append("\(file.lastPathComponent): \(key)") }
            }
        }
        XCTAssertTrue(missing.isEmpty, "chaînes absentes du catalogue :\n" + missing.joined(separator: "\n"))
    }

    func testBothLanguagesAreShippedInTheBundle() {
        let localizations = Bundle(for: AuthManager.self).localizations
        XCTAssertTrue(localizations.contains("fr"), "\(localizations)")
        XCTAssertTrue(localizations.contains("en"), "\(localizations)")
    }

    func testEnglishLookupWorksAtRuntime() throws {
        let bundle = Bundle(for: AuthManager.self)
        let path = try XCTUnwrap(bundle.path(forResource: "en", ofType: "lproj"))
        let en = try XCTUnwrap(Bundle(path: path))
        XCTAssertEqual(en.localizedString(forKey: "Supprimer", value: nil, table: nil), "Delete")
        XCTAssertEqual(en.localizedString(forKey: "undo_button", value: nil, table: nil), "Undo")
    }

    func testFrenchLookupWorksAtRuntime() throws {
        let bundle = Bundle(for: AuthManager.self)
        let path = try XCTUnwrap(bundle.path(forResource: "fr", ofType: "lproj"))
        let fr = try XCTUnwrap(Bundle(path: path))
        XCTAssertEqual(fr.localizedString(forKey: "undo_button", value: nil, table: nil), "Annuler")
    }

    func testDemoContentFollowsInterfaceLanguage() {
        let cards = MockData.inbox()
        XCTAssertEqual(cards.count, 12)
        if MockData.isFrench {
            XCTAssertTrue(cards[0].subject.contains("facture"))
        } else {
            XCTAssertTrue(cards[0].subject.contains("bill"))
        }
        XCTAssertFalse(MockData.body(for: "mock-2").isEmpty)
    }
}
