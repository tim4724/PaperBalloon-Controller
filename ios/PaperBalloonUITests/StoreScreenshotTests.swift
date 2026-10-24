import XCTest

/// Smoke test + store-screenshot capture in one pass, run once per theme (light/dark):
/// walks home → game info sheet → profile sheet → manual code entry → About, asserting
/// each screen's key content (manifest load, live/soon status, code gating, version
/// label), then deep-links into the HexStacker controller's `?scenario=playing` preview
/// (the game's own gallery harness, shipped in its production bundle — renders the
/// in-game touchpad with a stubbed connection, no live room needed). One full-screen
/// PNG per stop is attached to the result bundle.
///
/// CI extracts the PNGs with `xcrun xcresulttool export attachments`. The flow
/// deliberately avoids the QR scanner (no camera in the simulator) and never talks to
/// a live relay — only the in-game step needs network, to fetch the controller page.
final class StoreScreenshotTests: XCTestCase {

    private let playerName = "Alex"
    private let roomCode = "A3KX9p"

    /// The controller's own gallery/test harness (ControllerTestHarness.js, shipped in
    /// the production bundle): renders the playing screen with a stubbed connection.
    /// Injected via the app's DEBUG `-uitest.deepLink` hook — Universal Links need a
    /// live AASA + Safari round-trip that a simulator test can't provide.
    private var inGameURL: String {
        "https://hexstacker.com/\(roomCode)?scenario=playing&name=\(playerName)&color=0"
    }

    /// Tiny Track's own harness (TestHarness.js): the lobby's car picker. Landscape-only —
    /// the page asks the launcher for landscape (CONTRACT §10) before its first paint.
    private var tinyTrackURL: String {
        "https://tinytrack.paperballoon.games/\(roomCode)?scenario=lobby-host&color=0"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testStoreFlowLight() throws {
        runStoreFlow(dark: false)
    }

    func testStoreFlowDark() throws {
        runStoreFlow(dark: true)
    }

    private func runStoreFlow(dark: Bool) {
        let suffix = dark ? "dark" : "light"
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        // First launch mints a random FunnyName — the NSArgumentDomain override pins
        // ProfileStore's UserDefaults key so assertions and screenshots are
        // deterministic. English and the interface style are forced the same way.
        let baseArguments = [
            "-pb_profile.name", playerName,
            // Local Network already asked (app DEBUG hook), so home shows "Searching for
            // rooms…" rather than the one-time ask.
            "-uitest.lanAsked", "YES",
            // ...and keeps it there (app DEBUG hook) instead of settling to "No rooms
            // found" after its grace period, which raced the assertions on CI.
            "-uitest.holdSearch", "YES",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            // Window-level override via the app's DEBUG hook — the documented
            // -UIUserInterfaceStyle launch arg proved unreliable on CI simulators.
            "-uitest.appearance", dark ? "dark" : "light",
        ]
        app.launchArguments = baseArguments
        app.launch()

        // ---- Home: catalog, tags, join dock, profile chip ----
        XCTAssertTrue(app.staticTexts["HexStacker"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Searching for rooms nearby…"].exists)
        snap("01-home-\(suffix)")
        XCTAssertTrue(app.staticTexts["Tiny Track"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Powder"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Beta"].firstMatch.exists)
        XCTAssertEqual(app.staticTexts.matching(identifier: "Coming soon").count, 1)
        XCTAssertTrue(app.staticTexts["Games"].firstMatch.exists)
        XCTAssertTrue(app.buttons["Scan code"].firstMatch.exists)
        XCTAssertTrue(app.buttons[playerName].firstMatch.exists)

        // ---- Game info sheet: manifest copy + join actions for the live game ----
        app.staticTexts["HexStacker"].firstMatch.tap()
        // Waits key on the sheet's own copy: the home card shows the players count too.
        let steps = app.staticTexts["Scan the room code it shows."]
        XCTAssertTrue(steps.waitForExistence(timeout: 5))
        // The numeric players chip (Game.playersRange over the manifest counts).
        XCTAssertTrue(app.staticTexts["1–8"].exists)
        // Give the muted gameplay trailer time to download (first locale only — it's
        // cached after) and render real frames; cover art shows if it isn't ready.
        Thread.sleep(forTimeInterval: 4)
        snap("02-game-info-\(suffix)")
        // Tap the dimmed area above the content-height sheet to dismiss it.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        XCTAssertTrue(steps.waitForNonExistence(timeout: 5))

        // ---- Profile sheet: seeded name round-trips through the field ----
        app.buttons[playerName].firstMatch.tap()
        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        XCTAssertEqual(nameField.value as? String, playerName)
        snap("03-profile-\(suffix)")
        app.buttons["Save"].firstMatch.tap()
        XCTAssertTrue(nameField.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons[playerName].firstMatch.exists)

        // ---- Manual code entry: empty-code gating; never submitted (no relay dependency) ----
        app.buttons["Enter code manually"].firstMatch.tap()
        let alert = app.alerts["Enter room code"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertFalse(alert.buttons["Play"].isEnabled)
        let codeField = alert.textFields.firstMatch
        codeField.tap()
        codeField.typeText(roomCode)
        XCTAssertTrue(alert.buttons["Play"].isEnabled)
        snap("04-enter-code-\(suffix)")
        alert.buttons["Cancel"].tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5))

        // ---- About: legal hub reachable, version label present ----
        app.buttons["About"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Privacy Policy"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Impressum"].exists)
        XCTAssertTrue(app.staticTexts["Version 1.0.0"].exists)
        snap("05-about-\(suffix)")

        // Once: a game page draws itself the same in either theme.
        guard !dark else { return }

        captureInGame(app, arguments: baseArguments + ["-uitest.deepLink", inGameURL], name: "06-in-game")
        captureInGame(
            app, arguments: baseArguments + ["-uitest.deepLink", tinyTrackURL], name: "07-tinytrack", landscape: true
        )
    }

    /// Relaunch straight into a controller's scenario harness and capture it once the
    /// "Joining…" cover has faded — after the turn, for a [landscape] page, which asks
    /// for it (CONTRACT §10) before its first paint.
    private func captureInGame(_ app: XCUIApplication, arguments: [String], name: String, landscape: Bool = false) {
        if landscape { XCUIDevice.shared.orientation = .landscapeLeft }
        app.launchArguments = arguments
        app.launch()
        // The game host's web view. The cover may already have faded by the time launch()
        // returns, so only require its absence, not its appearance.
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 15))
        if landscape {
            let window = app.windows.firstMatch
            let turned = NSPredicate { _, _ in window.frame.width > window.frame.height }
            XCTAssertEqual(
                XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: turned, object: nil)], timeout: 15),
                .completed
            )
        }
        let joining = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'Joining'")
        ).firstMatch
        // The shell fades the cover on its injected __firstFrame signal, so the
        // cover's absence means the page has rendered (not merely loaded).
        XCTAssertTrue(joining.waitForNonExistence(timeout: 30))
        // ...but on a slow CI runner that frame can still be waiting for WebKit's
        // compositor, leaving a flat page background on screen.
        XCTAssertTrue(waitForPaint(timeout: 15))
        // Fonts and the touchpad canvas; Tiny Track's 3D car previews take longer.
        Thread.sleep(forTimeInterval: landscape ? 2 : 1)
        let screenshot = XCUIScreen.main.screenshot()
        // A page that ended its session (gameEnded — e.g. one that joined the fake room
        // instead of laying out its scenario) has popped back home: fail rather than
        // keep a capture of whatever replaced it.
        XCTAssertTrue(app.webViews.firstMatch.exists)
        if landscape {
            let frame = app.windows.firstMatch.frame
            XCTAssertGreaterThan(frame.width, frame.height)
        }
        attach(screenshot, name: name, landscape: landscape)
    }

    /// Polls until the screen below the status bar holds more than a few coarse colours:
    /// a blank page is one flat colour, any rendered controller well over a dozen.
    private func waitForPaint(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let image = XCUIScreen.main.screenshot().image.cgImage, coarseColours(image) > 4 { return true }
            Thread.sleep(forTimeInterval: 0.5)
        } while Date() < deadline
        return false
    }

    private func coarseColours(_ image: CGImage) -> Int {
        let w = 48, h = 96
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let context = CGContext(
            data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        var seen = Set<UInt32>()
        for y in (h / 10)..<h {  // row 0 is the top: skip the status bar
            for x in 0..<w {
                let i = (y * w + x) * 4
                seen.insert(UInt32(pixels[i] >> 4) << 8 | UInt32(pixels[i + 1] >> 4) << 4 | UInt32(pixels[i + 2] >> 4))
            }
        }
        return seen.count
    }

    private func snap(_ name: String) {
        attach(XCUIScreen.main.screenshot(), name: name, landscape: false)
    }

    /// Attaches a full-screen capture to the result bundle; extract with
    /// `xcrun xcresulttool export attachments --path <xcresult> --output-path <dir>`.
    ///
    /// The capture's pixels are always the portrait framebuffer. The image's orientation
    /// metadata, which the PNG drops anyway, isn't reliably set on CI either, so
    /// [landscape] turns the pixels itself: the landscapeLeft UI sits a quarter turn
    /// clockwise in the framebuffer, so it rotates them a quarter turn back.
    private func attach(_ screenshot: XCUIScreenshot, name: String, landscape: Bool) {
        let attachment: XCTAttachment
        if landscape, let image = screenshot.image.cgImage, image.width < image.height {
            let context = CGContext(
                data: nil, width: image.height, height: image.width, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )!
            context.translateBy(x: CGFloat(image.height), y: 0)
            context.rotate(by: .pi / 2)
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            attachment = XCTAttachment(data: UIImage(cgImage: context.makeImage()!).pngData()!, uniformTypeIdentifier: "public.png")
        } else {
            attachment = XCTAttachment(screenshot: screenshot)
        }
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
