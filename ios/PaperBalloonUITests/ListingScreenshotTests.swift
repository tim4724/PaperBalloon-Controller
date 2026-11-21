import XCTest

/// The App Store listing's app screenshots, on an iPhone 14 Plus (6.5") and an iPhone Duo.
/// Run by `tools/store_screenshots.py`, which sets the environment below, stands up the
/// nearby room, and writes the files into `store/`; skipped otherwise, so CI never runs it.
///
/// The script takes each capture itself (`simctl io screenshot`): XCUIScreenshot of the
/// Duo's inner screen comes out a pixel short of App Store Connect's exact size. A shot is
/// a marker file in `SNAP_DIR`, named for the shot; the test waits until the script has
/// captured the screen and removed it.
///
///   SNAP_DIR        where markers go
///   LISTING_LOCALE  the app's language: en or de
///   LISTING_ROOM    the nearby room's label, as `fake_room.py` advertises it
///   DUO_POSE        open or folded on the Duo (set in DeviceHub); absent on a phone
final class ListingScreenshotTests: XCTestCase {

    private let env = ProcessInfo.processInfo.environment
    private var snapDir: String { env["SNAP_DIR"]! }
    private var locale: String { env["LISTING_LOCALE"] ?? "en" }

    override func setUpWithError() throws {
        try XCTSkipUnless(env["SNAP_DIR"] != nil, "run by tools/store_screenshots.py")
        continueAfterFailure = false
        if env["DUO_POSE"] == nil { XCUIDevice.shared.orientation = .portrait }
    }

    /// Home with a room on the TV nearby. Needs the script's nearby room up.
    func testHomeNearby() {
        let app = launch(dark: false, holdSearch: false)
        let room = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", env["LISTING_ROOM"]!)).firstMatch
        XCTAssertTrue(room.waitForExistence(timeout: 30))
        Thread.sleep(forTimeInterval: 3)  // the card's arrival, the balloons settling
        snap("home-nearby")
    }

    /// HexStacker's game sheet, dark, over home still scrolled to the top.
    func testGamePage() {
        let app = launch(dark: true, holdSearch: true)
        let title = app.staticTexts["HexStacker"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        // The poster art above the title: a coordinate tap doesn't scroll home, as
        // tapping the title does wherever the join dock covers it.
        title.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(CGVector(dx: 0, dy: -60)).tap()
        // The sheet repeats the poster's players chip.
        let chips = app.staticTexts.matching(NSPredicate(format: "label == '1–8'"))
        let open = NSPredicate { _, _ in chips.count >= 2 }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: open, object: nil)], timeout: 10), .completed)
        Thread.sleep(forTimeInterval: 6)  // the slide-up, then the trailer's first frames
        snap("game-page")
    }

    /// Tiny Track's car picker (its own preview harness), landscape. The page is English
    /// whatever the app's language.
    func testTinyTrack() {
        if env["DUO_POSE"] == nil { XCUIDevice.shared.orientation = .landscapeLeft }
        let app = launch(dark: false, holdSearch: true, extra: [
            "-uitest.deepLink", "https://tinytrack.paperballoon.games/A3KX9p?scenario=lobby-host&color=0",
        ])
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 15))
        let window = app.windows.firstMatch
        let turned = NSPredicate { _, _ in window.frame.width > window.frame.height }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: turned, object: nil)], timeout: 15), .completed)
        // The cover fades on the page's first painted frame ("Joining…" / "Verbinden…").
        let cover = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", locale == "de" ? "Verbinden" : "Joining"))
        XCTAssertTrue(cover.firstMatch.waitForNonExistence(timeout: 30))
        Thread.sleep(forTimeInterval: 4)  // Tiny Track's 3D car previews
        XCTAssertTrue(app.webViews.firstMatch.exists)  // still in the game, not back home
        snap("tiny-track")
    }

    private func launch(dark: Bool, holdSearch: Bool, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        // The same DEBUG hooks as StoreScreenshotTests: pinned name, Local Network already
        // asked, and (holdSearch) "Searching…" held rather than settling to "No rooms found".
        app.launchArguments = [
            "-pb_profile.name", "Alex",
            "-uitest.lanAsked", "YES",
            "-uitest.holdSearch", holdSearch ? "YES" : "NO",
            "-AppleLanguages", "(\(locale))",
            "-AppleLocale", locale == "de" ? "de_DE" : "en_US",
            "-uitest.appearance", dark ? "dark" : "light",
        ] + extra
        app.launch()
        return app
    }

    private func snap(_ name: String) {
        let marker = URL(fileURLWithPath: snapDir).appendingPathComponent(name).path
        XCTAssertTrue(FileManager.default.createFile(atPath: marker, contents: nil))
        let deadline = Date().addingTimeInterval(30)
        while FileManager.default.fileExists(atPath: marker), Date() < deadline {
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker), "the script never captured \(name)")
    }
}
