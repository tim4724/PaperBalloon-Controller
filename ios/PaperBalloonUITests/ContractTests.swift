import XCTest

/// The launcher's half of CONTRACT.md, end to end, through the contract test controller
/// (the site repo's controller-test.html, served at `page`). Each test opens the page in
/// the game host and taps the page's own buttons, so every call crosses the real bridge,
/// then asserts both ends: the page's readouts and what the launcher did. Only the page
/// needs network, like StoreScreenshotTests' in-game step: a paperballoon.games subdomain
/// loads verbatim (JoinResolver), so no room, relay or display is involved. §4's status-bar
/// icons aren't visible to XCUITest; ContractTest.kt covers them on Android.
final class ContractTests: XCTestCase {

    /// The App Link any build reaches the deployed page by (the site repo's README,
    /// "Reaching it from the app").
    private let page = "https://test.paperballoon.games/PBTEST"
    private let playerName = "Alex"
    private let newName = "Sam"
    private let app = XCUIApplication()
    /// The page's buttons are `buttons`, except its aria-pressed ones (the §9 and §10
    /// pickers), which WebKit exposes as `switches`.
    private var web: XCUIElement { app.webViews.firstMatch }
    private var home: XCUIElement { app.staticTexts["HexStacker"] }

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments = [
            "-pb_profile.name", playerName,
            // DEBUG hooks, as in StoreScreenshotTests: Local Network already asked, and
            // the deep link Universal Links can't deliver in a simulator test.
            "-uitest.lanAsked", "YES",
            "-uitest.deepLink", page,
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
        ]
        app.launch()
        // The page's script has run once it has filled in its mode badge, and touches reach
        // it once the launcher's join cover has faded (on the page's first frame). The load
        // from a CI runner has taken over 30 s.
        XCTAssertTrue(web.staticTexts["launcher shell"].waitForExistence(timeout: 60))
        let joining = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Joining'")).firstMatch
        XCTAssertTrue(joining.waitForNonExistence(timeout: 30))
    }

    /// §1–2: the page reads the launcher's name, and a rename in the launcher's sheet reaches it.
    func testRenameGoesThroughTheLauncherSheet() {
        XCTAssertTrue(web.staticTexts["\"\(playerName)\""].waitForExistence(timeout: 5))
        web.buttons["Rename"].tap()
        let field = nameField()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        // Return (the field's Done) saves: nothing to aim at while the rising keyboard is
        // still moving the sheet, which made a Save tap miss on a real phone.
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: playerName.count) + newName + "\n")
        XCTAssertTrue(web.staticTexts["\"\(newName)\""].waitForExistence(timeout: 5))
    }

    /// §2: a dismissed sheet resolves editName with null, and the player stays in the game.
    func testDismissedSheetResolvesNull() {
        web.buttons["Rename"].tap()
        let title = app.staticTexts["Name"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        // Dragged down off the screen, as a hand would.
        title.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1)))
        XCTAssertTrue(title.waitForNonExistence(timeout: 5))
        XCTAssertTrue(logLine("editName → null").waitForExistence(timeout: 5))
        XCTAssertTrue(web.exists)
    }

    /// §3
    func testLeaveGoesHome() {
        web.buttons["Leave"].tap()
        awaitHome()
    }

    /// §3: the first exit wins, here gameEnded, so home shows its message.
    func testGameEndedBeatsALaterLeave() {
        web.buttons["gameEnded + leave"].tap()
        // The message first: it clears itself 5 s after the game ends, which awaitHome's
        // queries can outlast on a slow CI simulator. It only ever shows on home.
        XCTAssertTrue(app.staticTexts["Room is full"].waitForExistence(timeout: 10))
        awaitHome()
    }

    /// §5: the page covers the whole screen and env(safe-area-inset-top) is the status bar.
    func testPageCoversTheScreenWithRealInsets() {
        XCTAssertEqual(web.frame.minY, 0)
        // The readout is "top / right / bottom / left".
        let insets = web.staticTexts.matching(NSPredicate(format: "label MATCHES '[1-9][0-9.]*px / .*'")).firstMatch
        XCTAssertTrue(insets.waitForExistence(timeout: 5))
    }

    /// §9: every page load starts at `leave`, where the swipe back goes home.
    func testSwipeBackLeavesByDefault() {
        swipeBack()
        awaitHome()
    }

    /// §9: `off` (and `page`, iOS having no system back) keeps the swipe for the game.
    func testSwipeBackOffDoesNothing() {
        web.switches["off"].tap()
        swipeBack()
        XCTAssertFalse(home.waitForExistence(timeout: 2))
        XCTAssertTrue(web.exists)
    }

    /// §10: only the literal 'landscape' turns; anything else is portrait again.
    func testSetOrientationTurnsAndResets() {
        web.switches["landscape"].tap()
        awaitWindow { $0.width > $0.height }
        // §9 has a "nonsense" too; §10's comes after it.
        web.switches.matching(identifier: "\"nonsense\"").element(boundBy: 1).tap()
        awaitWindow { $0.width < $0.height }
    }

    /// The launcher's name sheet's field, which opens showing the name in force (the page
    /// has a text field of its own).
    private func nameField() -> XCUIElement {
        app.textFields.matching(NSPredicate(format: "value == %@", playerName)).firstMatch
    }

    private func logLine(_ line: String) -> XCUIElement {
        web.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", line)).firstMatch
    }

    private func awaitHome() {
        XCTAssertTrue(home.waitForExistence(timeout: 10))
        XCTAssertTrue(web.waitForNonExistence(timeout: 5))
    }

    /// In from the leading edge, as a thumb would: from x = 0, where one coming in off the
    /// bezel lands. UIKit's edge zone is a few points wide, and a synthesized touch even
    /// 4 pt in (1% of a Pro Max) can miss it.
    private func swipeBack() {
        let window = app.windows.firstMatch
        window.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
    }

    private func awaitWindow(_ shape: @escaping (CGRect) -> Bool, file: StaticString = #filePath, line: UInt = #line) {
        let window = app.windows.firstMatch
        let turned = NSPredicate { _, _ in shape(window.frame) }
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: turned, object: nil)], timeout: 15),
            .completed, file: file, line: line
        )
    }
}
