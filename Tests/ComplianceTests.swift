import XCTest
@testable import MailSwipe

final class ComplianceTests: XCTestCase {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private func appBundle() -> Bundle { Bundle(for: AuthManager.self) }

    func testPrivacyManifestIsShippedAndDeclaresNoTracking() throws {
        let url = try XCTUnwrap(appBundle().url(forResource: "PrivacyInfo", withExtension: "xcprivacy"), "manifeste absent du bundle")
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any])
        XCTAssertEqual(plist["NSPrivacyTracking"] as? Bool, false)
        XCTAssertNotNil(plist["NSPrivacyCollectedDataTypes"])
        XCTAssertNotNil(plist["NSPrivacyAccessedAPITypes"])
    }

    /// Si quelqu'un réintroduit une API « raison requise », le manifeste doit la déclarer.
    func testNoUndeclaredRequiredReasonAPI() throws {
        let url = try XCTUnwrap(appBundle().url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any])
        let declared = (plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]] ?? []).compactMap { $0["NSPrivacyAccessedAPIType"] as? String }

        let triggers: [String: [String]] = [
            "NSPrivacyAccessedAPICategoryUserDefaults": ["UserDefaults", "@AppStorage", "NSUserDefaults"],
            "NSPrivacyAccessedAPICategorySystemBootTime": ["systemUptime", "mach_absolute_time"],
            "NSPrivacyAccessedAPICategoryFileTimestamp": ["creationDate", "contentModificationDateKey", "fileModificationDate", "NSFileCreationDate"],
            "NSPrivacyAccessedAPICategoryDiskSpace": ["volumeAvailableCapacity", "NSFileSystemFreeSize", "systemFreeSize"],
            "NSPrivacyAccessedAPICategoryActiveKeyboards": ["activeInputModes"],
        ]
        let sources = repoRoot.appendingPathComponent("Sources")
        let files = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" } ?? []
        XCTAssertFalse(files.isEmpty, "sources introuvables : \(sources.path)")

        for file in files {
            let code = try String(contentsOf: file, encoding: .utf8)
                .components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") && !$0.trimmingCharacters(in: .whitespaces).hasPrefix("///") }
                .joined(separator: "\n")
            for (category, symbols) in triggers where !declared.contains(category) {
                for symbol in symbols {
                    XCTAssertFalse(code.contains(symbol), "\(file.lastPathComponent) utilise \(symbol) sans déclarer \(category)")
                }
            }
        }
    }

    func testExportComplianceKeyIsSet() {
        XCTAssertEqual(appBundle().object(forInfoDictionaryKey: "ITSAppUsesNonExemptEncryption") as? Bool, false)
    }

    func testPrivacyPolicyMentionsEveryRequestedGoogleScope() throws {
        let policy = try String(contentsOf: repoRoot.appendingPathComponent("docs/PRIVACY.md"), encoding: .utf8)
        for scope in Config.scopes.split(separator: " ") {
            XCTAssertTrue(policy.contains(scope), "la politique ne mentionne pas \(scope)")
        }
    }

    func testPrivacyPolicyContainsGoogleLimitedUseStatement() throws {
        let policy = try String(contentsOf: repoRoot.appendingPathComponent("docs/PRIVACY.md"), encoding: .utf8)
        XCTAssertTrue(policy.contains("Google API Services User Data Policy"))
        XCTAssertTrue(policy.contains("Limited Use"))
    }

    func testPolicyAndSupportLinksAreHTTPS() {
        XCTAssertEqual(Config.privacyPolicyURL.scheme, "https")
        XCTAssertEqual(Config.supportURL.scheme, "https")
    }
}
