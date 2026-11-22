import XCTest

/// Every launcher screen on the iPhone Duo, in light and dark, and the HexStacker and Tiny
/// Track controllers, for checking layouts across its screens. Skipped on any other device.
///
/// Nothing can fold or turn the Duo simulator from a test or the command line (Xcode 27.2:
/// XCTest has no hinge, and DeviceHub's pose overrides `XCUIDevice` and `devicectl`
/// orientation requests). Set the pose with DeviceHub's pose and rotate buttons, pass it in,
/// and run once per pose:
///
///     TEST_RUNNER_DUO_POSE=folded xcodebuild test … -only-testing:PaperBalloonUITests/DuoScreenshotTests
///
/// `folded` is the cover screen; `open` the inner screen held as a book (landscape);
/// `upright` the inner screen turned upright; `phone` runs the same stops on any other
/// iPhone, to compare against. Each capture is named `<pose>-<screen>` and turned so the
/// interface reads upright; export with `xcresulttool export attachments`.
final class DuoScreenshotTests: XCTestCase {

    private let playerName = "Alex"
    private let roomCode = "A3KX9p"

    private var pose: String { ProcessInfo.processInfo.environment["DUO_POSE"] ?? "folded" }

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] == "iPhone19,4" || pose == "phone",
            "iPhone Duo only"
        )
    }

    func testLauncherLight() { captureLauncher(dark: false) }

    func testLauncherDark() { captureLauncher(dark: true) }

    /// The controllers' own preview harnesses, as in StoreScreenshotTests. A game page
    /// draws itself the same in either theme.
    func testInGame() {
        captureGame("https://hexstacker.com/\(roomCode)?scenario=playing&name=\(playerName)&color=0", "6-hexstacker")
        captureGame("https://tinytrack.paperballoon.games/\(roomCode)?scenario=lobby-host&color=0", "7-tinytrack")
    }

    // MARK: - Stops

    /// Home and each sheet and screen over it, every one from a fresh launch: no sheet has a
    /// close button, and how one dismisses changes with the screen.
    private func captureLauncher(dark: Bool) {
        let theme = dark ? "dark" : "light"

        let app = launch(dark: dark)
        XCTAssertTrue(app.staticTexts["HexStacker"].firstMatch.waitForExistence(timeout: 10))
        snap("1-home-\(theme)")

        app.staticTexts["HexStacker"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Scan the room code it shows."].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 2)  // the sheet's slide-up and the trailer's first frames
        snap("2-game-sheet-\(theme)")

        let profile = launch(dark: dark)
        profile.buttons[playerName].firstMatch.tap()
        XCTAssertTrue(profile.textFields.firstMatch.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1)
        snap("3-name-sheet-\(theme)")

        let code = launch(dark: dark)
        code.buttons["Enter code manually"].firstMatch.tap()
        XCTAssertTrue(code.keyboards.firstMatch.waitForExistence(timeout: 5))
        code.typeText(String(roomCode.dropLast()))
        Thread.sleep(forTimeInterval: 1)
        snap("4-code-sheet-\(theme)")

        let about = launch(dark: dark)
        about.buttons["About"].firstMatch.tap()
        XCTAssertTrue(about.staticTexts["Privacy Policy"].waitForExistence(timeout: 5))
        snap("5-about-\(theme)")
    }

    private func captureGame(_ url: String, _ name: String) {
        let app = launch(dark: false, extra: ["-uitest.deepLink", url])
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 15))
        let joining = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Joining'")).firstMatch
        XCTAssertTrue(joining.waitForNonExistence(timeout: 30))
        XCTAssertFalse(app.buttons["Try again"].exists, "the page failed to load")
        Thread.sleep(forTimeInterval: 3)  // fonts, the touchpad canvas, Tiny Track's 3D cars
        snap(name)
    }

    // MARK: - Helpers

    private func launch(dark: Bool, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        // Pinned name, asked-for Local Network held at "Searching…", English, and the
        // theme: the same DEBUG hooks as StoreScreenshotTests.
        app.launchArguments = [
            "-pb_profile.name", playerName,
            "-uitest.lanAsked", "YES",
            "-uitest.holdSearch", "YES",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-uitest.appearance", dark ? "dark" : "light",
        ] + extra
        app.launch()
        return app
    }

    /// Attaches the screen the app is on, drawn upright. The main screen is the cover, black
    /// while the Duo is open; the inner one is the larger. The pixels come in the panel's
    /// own orientation and the window frame doesn't say which way the interface turned on
    /// it, but the image's orientation does (on a local simulator — CI's is unreliable,
    /// see StoreScreenshotTests).
    private func snap(_ name: String) {
        let image = (pose == "open" || pose == "upright"
            ? XCUIScreen.screens.map { $0.screenshot() }.max { area($0) < area($1) }!
            : XCUIScreen.main.screenshot()).image
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let upright = UIGraphicsImageRenderer(size: image.size, format: format).pngData { _ in image.draw(at: .zero) }
        let attachment = XCTAttachment(data: upright, uniformTypeIdentifier: "public.png")
        attachment.name = "\(pose)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func area(_ screenshot: XCUIScreenshot) -> Int {
        screenshot.image.cgImage.map { $0.width * $0.height } ?? 0
    }
}
