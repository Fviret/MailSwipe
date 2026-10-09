import XCTest

/// Parcours utilisateur de bout en bout, en mode démo : données jetables, notifications neutralisées,
/// délai d'annulation de 1,5 s (arguments `-ui-*`, voir LaunchOptions.swift).
final class MailSwipeUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(french: Bool = true, extra: [String] = []) {
        app.launchArguments = ["-ui-testing", "-ui-undo-delay", "6"] + extra + (french
            ? ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
            : ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"])
        app.launch()
    }

    // MARK: - Aides

    private func element(_ label: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func element(containing text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private var card: XCUIElement { app.descendants(matching: .any).matching(identifier: "card.top").firstMatch }
    private func legend(_ name: String) -> XCUIElement { app.buttons["legend.\(name)"] }
    private var undo: XCUIElement { app.buttons["undo.button"] }

    private func tab(_ title: String) -> XCUIElement {
        app.tabBars.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    }

    @discardableResult
    private func waitForCard(containing text: String, timeout: TimeInterval = 6, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", text), object: card)
        let ok = XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
        XCTAssertTrue(ok, "la carte du dessus ne contient pas « \(text) » : \(card.label)", file: file, line: line)
        return ok
    }

    private func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval = 12, file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: timeout), .completed, file: file, line: line)
    }

    // MARK: - Lancement

    func testLaunchShowsDemoBannerFirstCardLegendAndTabs() {
        launch()
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        XCTAssertTrue(card.label.contains("Free Mobile"))
        XCTAssertTrue(card.label.contains("Ta facture Septembre est disponible"))
        XCTAssertTrue(element(containing: "Mode démo").exists)
        for name in ["delete", "snooze", "archive", "reply"] { XCTAssertTrue(legend(name).exists, name) }
        for title in ["Inbox", "Archive", "Snoozés", "Réglages"] { XCTAssertTrue(tab(title).exists, title) }
        XCTAssertTrue(app.buttons["inbox.refresh"].exists)
    }

    func testEnglishInterface() {
        launch(french: false)
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        XCTAssertTrue(card.label.contains("Your September bill is available"))
        XCTAssertEqual(legend("delete").label, "Delete")
        XCTAssertEqual(legend("reply").label, "Reply")
        XCTAssertTrue(tab("Settings").exists)
        XCTAssertTrue(tab("Snoozed").exists)
        legend("archive").tap()
        XCTAssertTrue(undo.waitForExistence(timeout: 4))
        XCTAssertEqual(undo.label, "Undo")
        XCTAssertTrue(element(containing: "Archived · Free Mobile").exists)
    }

    // MARK: - Annulation et boutons

    func testArchiveThenUndoRestoresTheCard() {
        launch()
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        legend("archive").tap()
        XCTAssertTrue(undo.waitForExistence(timeout: 4))
        XCTAssertTrue(element(containing: "Archivé · Free Mobile").exists)
        undo.tap()
        waitForCard(containing: "Free Mobile")
        waitUntilGone(undo)
    }

    func testArchivedMailAppearsInTheArchiveTab() {
        launch()
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        legend("archive").tap()
        XCTAssertTrue(undo.waitForExistence(timeout: 4))
        waitUntilGone(undo)
        tab("Archive").tap()
        XCTAssertTrue(app.staticTexts["Ta facture Septembre est disponible"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Free Mobile"].exists)
        XCTAssertFalse(app.staticTexts["Aucun mail archivé"].exists)
    }

    func testDeleteButtonShowsToastAndAdvancesToNextMail() {
        launch()
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        legend("delete").tap()
        XCTAssertTrue(element(containing: "Supprimé · Free Mobile").waitForExistence(timeout: 4))
        waitForCard(containing: "Camille Dupont")
    }

    // MARK: - Gestes réels

    func testSwipeLeftDeletes() {
        launch()
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        card.swipeLeft()
        XCTAssertTrue(element(containing: "Supprimé · Free Mobile").waitForExistence(timeout: 5))
        waitForCard(containing: "Camille Dupont")
    }

    func testSwipeUpArchives() {
        launch()
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        card.swipeUp()
        XCTAssertTrue(element(containing: "Archivé · Free Mobile").waitForExistence(timeout: 5))
    }

    func testSwipeRightOpensReplyAndSwipeDownOpensSnooze() {
        launch()
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        card.swipeRight()
        XCTAssertTrue(app.navigationBars["Répondre"].waitForExistence(timeout: 5))
        app.buttons["Annuler"].tap()
        waitForCard(containing: "Free Mobile")

        card.swipeDown()
        XCTAssertTrue(app.navigationBars["Snoozer"].waitForExistence(timeout: 5))
        app.buttons["Annuler"].tap()
        waitForCard(containing: "Free Mobile")
    }

    func testShortDragSpringsBackWithoutAction() {
        launch()
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        let start = card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: card.coordinate(withNormalizedOffset: CGVector(dx: 0.58, dy: 0.5)))
        XCTAssertFalse(undo.exists)
        XCTAssertTrue(card.label.contains("Free Mobile"))
    }

    // MARK: - Lecture

    func testTapOpensFullMailThenCloses() {
        launch()
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        card.tap()
        XCTAssertTrue(app.navigationBars["Mail"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Ta facture Septembre est disponible"].exists)
        XCTAssertTrue(element(containing: "mail de démonstration").waitForExistence(timeout: 5))
        app.buttons["Fermer"].tap()
        waitUntilGone(app.navigationBars["Mail"])
    }

    func testReplyFromTheReadingScreen() {
        launch()
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        card.tap()
        XCTAssertTrue(app.navigationBars["Mail"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Répondre"].tap()
        XCTAssertTrue(app.navigationBars["Répondre"].waitForExistence(timeout: 5))
    }

    // MARK: - Réponse

    func testReplyFlowRequiresTextThenSchedulesTheSend() {
        launch()
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        legend("reply").tap()
        XCTAssertTrue(app.navigationBars["Répondre"].waitForExistence(timeout: 5))
        XCTAssertTrue(element("À Free Mobile").exists)
        XCTAssertTrue(element("facture@free.fr").exists)

        let send = app.buttons["reply.send"]
        XCTAssertFalse(send.isEnabled, "pas d'envoi d'une réponse vide")
        app.buttons["Merci, bien reçu !"].tap()
        XCTAssertTrue(send.isEnabled)
        send.tap()

        XCTAssertTrue(element(containing: "Réponse à Free Mobile en cours d'envoi").waitForExistence(timeout: 5))
        waitForCard(containing: "Camille Dupont")
        undo.tap()
        waitForCard(containing: "Free Mobile")
    }

    func testReplySheetShowsTheOriginalMail() {
        launch()
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        legend("reply").tap()
        XCTAssertTrue(app.navigationBars["Répondre"].waitForExistence(timeout: 5))
        app.staticTexts["Mail d'origine"].tap()
        XCTAssertTrue(element(containing: "mail de démonstration").waitForExistence(timeout: 5))
    }

    func testTypingAReplyEnablesSend() {
        launch()
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        legend("reply").tap()
        let editor = app.textViews["reply.text"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("Bien reçu")
        XCTAssertTrue(app.buttons["reply.send"].isEnabled)
    }

    func testNoReplySenderIsRefusedWithAnExplanation() {
        launch()
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        for next in ["Camille Dupont", "Amazon", "Julien Martin", "Banque en ligne"] {
            legend("delete").tap()
            waitForCard(containing: next)
        }
        legend("reply").tap()
        XCTAssertTrue(app.alerts["Impossible de répondre"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(containing: "ne pas répondre").exists)
        app.alerts.buttons["OK"].tap()
        waitForCard(containing: "Banque en ligne")
        XCTAssertFalse(app.navigationBars["Répondre"].exists)
    }

    // MARK: - Snooze

    func testSnoozeFlowThenRemoveFromSnoozedTab() {
        launch()
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        legend("snooze").tap()
        XCTAssertTrue(app.navigationBars["Snoozer"].waitForExistence(timeout: 5))
        for option in ["Dans 1 heure", "Ce soir (18h)", "Demain matin (8h)", "La semaine prochaine"] {
            XCTAssertTrue(app.buttons[option].exists, option)
        }
        app.buttons["Demain matin (8h)"].tap()
        XCTAssertTrue(element(containing: "Snoozé · Free Mobile").waitForExistence(timeout: 5))
        waitUntilGone(undo)

        tab("Snoozés").tap()
        XCTAssertTrue(app.staticTexts["Ta facture Septembre est disponible"].waitForExistence(timeout: 4))
        XCTAssertTrue(element(containing: "Retour").exists)
        app.buttons["snoozed.remove"].tap()
        XCTAssertTrue(app.staticTexts["Rien en pause"].waitForExistence(timeout: 4))
    }

    func testSnoozeCanBeUndone() {
        launch()
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        legend("snooze").tap()
        app.buttons["Dans 1 heure"].tap()
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        undo.tap()
        waitForCard(containing: "Free Mobile")
        tab("Snoozés").tap()
        XCTAssertTrue(app.staticTexts["Rien en pause"].waitForExistence(timeout: 4))
    }

    // MARK: - Onglets

    func testEmptyStatesOfArchiveAndSnoozedTabs() {
        launch()
        tab("Archive").tap()
        XCTAssertTrue(app.staticTexts["Aucun mail archivé"].waitForExistence(timeout: 4))
        tab("Snoozés").tap()
        XCTAssertTrue(app.staticTexts["Rien en pause"].waitForExistence(timeout: 4))
    }

    func testSettingsScreen() {
        launch()
        tab("Réglages").tap()
        XCTAssertTrue(app.navigationBars["Réglages"].waitForExistence(timeout: 4))
        for text in ["Mode démo actif", "Politique de confidentialité", "Assistance", "→ Droite : Répondre", "← Gauche : Supprimer", "↑ Haut : Archiver"] {
            XCTAssertTrue(element(containing: text).exists, text)
        }
        XCTAssertTrue(element(containing: "Aucun serveur MailSwipe").exists)
        XCTAssertFalse(app.buttons["Quitter le mode démo"].exists, "sans Client ID, pas d'autre mode")
    }

    func testRefreshRestoresMailsFromTheSource() {
        launch()
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        legend("delete").tap()
        waitForCard(containing: "Camille Dupont")
        waitUntilGone(undo)
        app.buttons["inbox.refresh"].tap()
        waitForCard(containing: "Free Mobile")
    }

    // MARK: - Boîte vide et pagination

    func testHandlingEveryMailShowsTheEmptyInbox() {
        launch()
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        let senders = ["Camille Dupont", "Amazon", "Julien Martin", "Banque en ligne", "The Tech Weekly", "Cabinet Dr Martin",
                       "FitClub", "Sophie Bernard", "Mondial Relay", "Thomas Leroy", "Podomètre"]
        for next in senders {
            legend("delete").tap()
            waitForCard(containing: next, timeout: 8)
        }
        legend("delete").tap()
        XCTAssertTrue(app.staticTexts["Boîte vide"].waitForExistence(timeout: 8))
        XCTAssertFalse(legend("delete").isEnabled, "plus rien à traiter")
    }

    // MARK: - Connexion

    func testSignInScreenWhenGmailIsConfiguredButNotConnected() {
        launch(extra: ["-ui-gmail-configured"])
        XCTAssertTrue(app.staticTexts["MailSwipe"].waitForExistence(timeout: 8))
        XCTAssertTrue(element(containing: "d'un simple geste").exists)
        XCTAssertTrue(app.buttons["Se connecter avec Gmail"].exists)
        XCTAssertFalse(app.buttons["Se connecter avec Gmail"].isEnabled, "pas de Client ID dans le dépôt")
        XCTAssertTrue(element("Politique de confidentialité").exists)
        app.buttons["Essayer en mode démo"].tap()
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        XCTAssertTrue(card.label.contains("Free Mobile"))
    }
}
