import UIKit
import SwiftUI

// MARK: - App delegate

@main final class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Audio-session setup lives in GameAudioSession (GameWebView.swift), paid on
        // first game join — the call talks to the audio server (tens of ms) and
        // nothing on the launch path plays sound.

        excludeWebKitFromBackup()
        return true
    }

    /// Keeps the web views' storage (localStorage, IndexedDB) out of iCloud and Finder
    /// backups. WebKit creates Library/WebKit on first use, so it is made here, before any
    /// web view; the flag on the folder covers everything WebKit later writes inside it.
    private func excludeWebKitFromBackup() {
        var dir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WebKit", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? dir.setResourceValues(values)
    }
}

// MARK: - Scene delegate

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    let router = AppRouter()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        #if DEBUG
        // UI-test hook: `-uitest.lanAsked YES` — LocalNetworkAsked is a file, out of
        // the argument domain's reach. Before the root view, which reads it at init.
        if UserDefaults.standard.bool(forKey: "uitest.lanAsked") { LocalNetworkAsked.set() }
        #endif

        let window = UIWindow(windowScene: windowScene)
        let root = RootHostingController(rootView: RootView(router: router))
        ChromeState.shared.host = root
        // First frames before SwiftUI paints must already be the background in the
        // correct light/dark variant (no white flash in dark mode): the launch screen's
        // own colour, which is PBPalette's background.
        window.backgroundColor = UIColor(named: "LaunchBackground")
        window.rootViewController = root
        self.window = window
        window.makeKeyAndVisible()

        // Posters dominate the first frame — start their off-main decodes now
        // rather than when each card's .task runs (after first paint).
        ArtCache.prewarm(ManifestStore.shared.games)

        // Cold-start deep link: connectionOptions only exist at scene connect,
        // so "consumed once, never replayed" holds by construction.
        if let url = connectionOptions.userActivities
            .first(where: { $0.activityType == NSUserActivityTypeBrowsingWeb })?.webpageURL {
            router.handleIncomingURL(url)
        }

        #if DEBUG
        // UI-test hooks (StoreScreenshotTests), read via the argument domain:
        // `-uitest.deepLink <url>` — Universal Links need a live AASA + Safari
        // round-trip, so simulator tests inject the join URL directly instead.
        // `-uitest.appearance dark|light` — forces the interface style at the window
        // (the `-UIUserInterfaceStyle` launch arg proved unreliable on CI simulators).
        if let link = UserDefaults.standard.string(forKey: "uitest.deepLink"),
           let url = URL(string: link) {
            router.handleIncomingURL(url)
        }
        if let style = UserDefaults.standard.string(forKey: "uitest.appearance") {
            window.overrideUserInterfaceStyle = style == "dark" ? .dark : .light
        }
        #endif
    }

    // Universal Links while running. A link replaces any live game page, but continue()
    // lands after willEnterForeground — the outgoing page would already have been told it's
    // visible and reconnected, so the display sees join, leave, join. willContinue comes
    // before the foreground, so the game host puts its page to sleep there.
    func scene(_ scene: UIScene, willContinueUserActivityWithType userActivityType: String) {
        guard userActivityType == NSUserActivityTypeBrowsingWeb else { return }
        NotificationCenter.default.post(name: .incomingLinkWillOpen, object: nil)
    }

    func scene(_ scene: UIScene, didFailToContinueUserActivityWithType userActivityType: String, error: Error) {
        guard userActivityType == NSUserActivityTypeBrowsingWeb else { return }
        NotificationCenter.default.post(name: .incomingLinkDidFail, object: nil)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb else { return }
        guard let url = userActivity.webpageURL else {
            // willContinue already put the game page to sleep — nothing will replace it.
            NotificationCenter.default.post(name: .incomingLinkDidFail, object: nil)
            return
        }
        router.handleIncomingURL(url)
    }
}

extension Notification.Name {
    /// A Universal Link is on its way in; the game page it will replace must not wake.
    static let incomingLinkWillOpen = Notification.Name("games.paperballoon.incomingLinkWillOpen")
    /// The announced link never arrived — the game page carries on.
    static let incomingLinkDidFail = Notification.Name("games.paperballoon.incomingLinkDidFail")
}

// MARK: - Root hosting controller

final class RootHostingController: UIHostingController<RootView> {

    override var preferredStatusBarStyle: UIStatusBarStyle {
        ChromeState.shared.statusBarStyle ?? .default
    }

    /// Whether an iPhone Duo is open, which puts the app on its inner screen; nil on any
    /// other iPhone, and until the hinge first reports.
    private var unfolded: Bool?

    /// Whether the device folds (an iPhone Duo), once its hinge has reported.
    static private(set) var hasHinge = false

    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 27.1, *) {
            view.addInteraction(UIHingeInteraction { [weak self] _, update in
                if update.hinge != nil { Self.hasHinge = true }
                self?.unfolded = switch update.hinge?.status {
                case .closed: false
                case .partiallyOpen, .fullyOpen: true
                default: nil
                }
            })
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        // Opening or closing a Duo moves the app to its other screen, but UIKit doesn't ask
        // for the orientations again, so home opened on the cover would stay a pillarboxed
        // phone after unfolding. Asked again once the move is over, by which time the hinge
        // has reported.
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            self?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }

    /// The only view controller in the window, so this narrows the Info.plist's
    /// landscape-inclusive superset down to what the current screen actually allows
    /// (CONTRACT.md §10). A game host takes what its page asked for. The launcher's own
    /// screens are portrait — home must not rotate just because the plist permits it.
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        locksOrientation ? ChromeState.shared.orientation ?? .portrait : .allButUpsideDown
    }

    /// Everywhere but the Duo's inner screen, where nothing is locked, a game page
    /// included: the page fills it whichever way it's held and lays itself out for that
    /// shape, or asks the player to turn. The screen is landscape-native, and iOS shows a
    /// portrait lock there as a phone on one half, and a landscape lock held upright
    /// unturned and cut off.
    var locksOrientation: Bool { !(unfolded ?? isOnLargeScreen) }

    /// Before the hinge first reports, the screen's short side tells: 600 pt or more is the
    /// Duo's inner screen, wider than any phone's. Only until then — once iOS has
    /// pillarboxed the app, the screen reports the pillarbox.
    private var isOnLargeScreen: Bool {
        guard let screen = view.window?.windowScene?.screen else { return false }
        return min(screen.bounds.width, screen.bounds.height) >= 600
    }
}

// MARK: - Chrome state

/// Status-bar style and interface orientation for the game host (the page's color scheme
/// sets the one, the page's request the other). Home indicator and edge-gesture
/// deferral are NOT here — those use SwiftUI's view-scoped persistentSystemOverlays/
/// defersSystemGestures on GameHostScreen, which cannot leak past that view's lifetime.
/// Orientation can't work that way: it is a window-scene property, and the reset must
/// be driven by the ROUTE (see AppRouter) so a pop can't leave home stuck in landscape.
@MainActor final class ChromeState {

    static let shared = ChromeState()

    weak var host: RootHostingController?

    var statusBarStyle: UIStatusBarStyle? {
        didSet { host?.setNeedsStatusBarAppearanceUpdate() }
    }

    /// What the game host allows (CONTRACT.md §10); nil on the launcher's own screens,
    /// which the root VC decides. `.landscape` covers both orientations rather than
    /// picking one: a controller held either way round must land right side up, and the
    /// launcher has no idea which hand the player uses.
    var orientation: UIInterfaceOrientationMask? {
        didSet {
            guard oldValue != orientation, let host else { return }
            // Order matters. setNeedsUpdate… makes UIKit re-read the root VC's
            // supportedInterfaceOrientations (already the new mask — this is a didSet);
            // requestGeometryUpdate then actually turns the window. Without the first
            // call the geometry request is rejected against the stale mask; without the
            // second the device only rotates if the player physically turns the phone.
            host.setNeedsUpdateOfSupportedInterfaceOrientations()
            host.view.window?.windowScene?
                .requestGeometryUpdate(.iOS(interfaceOrientations: host.supportedInterfaceOrientations))
        }
    }

    func reset() {
        statusBarStyle = nil
        orientation = nil
    }

    private init() {}
}
