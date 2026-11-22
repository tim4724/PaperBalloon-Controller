import SwiftUI
import UIKit

// MARK: - ProminentGlassButton

/// A prominent action on tinted glass where the OS has it (iOS 26), matching ChromeGlass
/// controls beside it; the filled button before. A modifier rather than an inline
/// `if #available` so the SDK-17 build compiles.
struct ProminentGlassButton: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.buttonStyle(.glassProminent)
        } else {
            content.buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - ChromeGlass

/// Liquid Glass on iOS 26 behind the home toolbar's pills. Earlier releases have no glass
/// in their toolbars, so they get `fallback`.
struct ChromeGlass<S: Shape>: ViewModifier {
    let shape: S
    var fallback: Color = .clear

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: shape)
        } else {
            content.background(fallback, in: shape)
        }
    }
}

// MARK: - RetryCover

/// Opaque "couldn't reach the server / try again" cover shown over a dead WebView
/// (host unreachable) — same copy and shape in the game host and the legal doc
/// viewer. The fill differs (a live game's surface vs the screen background), so the
/// caller passes both it and its content color; the button follows the palette accent.
struct RetryCover: View {
    let background: Color
    let foreground: Color
    let onRetry: () -> Void

    @Environment(\.pbPalette) private var palette

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            VStack(spacing: 24) {
                // Short form — the Retry button already says "try again".
                Text(String(localized: "Couldn’t reach the server."))
                    .font(.pbBodyLarge)
                    .foregroundStyle(foreground)
                    .multilineTextAlignment(.center)
                Button(action: onRetry) {
                    // The label must pair with the fill: the system's default white is
                    // invisible on the dark palette's near-white primary.
                    Text(String(localized: "Try again"))
                        .font(.pbTitleMedium)
                        .foregroundStyle(palette.onPrimary)
                }
                .modifier(ProminentGlassButton())
                .controlSize(.large)
                .tint(palette.primary)
            }
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - JoiningCover

/// "Joining…" cover over a page that hasn't painted yet: home shows it while the relay
/// resolves a code, the game host while the controller loads, so one join reads as a
/// single loading screen. The fill differs (a themed game surface vs the screen
/// background), so the caller passes it and its content color — as does the message:
/// home hasn't discovered the game yet, the host names it.
struct JoiningCover: View {
    let message: String
    let background: Color
    let foreground: Color

    var body: some View {
        background
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: 16) {
                    ProgressView()
                    Text(message)
                        .font(.pbBodyMedium)
                        .foregroundStyle(foreground)
                }
            }
    }
}

// MARK: - ArtCache

/// Process-wide memoized async decode of artwork, keyed by manifest art path:
/// the bundled copy when one ships (assets are flattened into the bundle root, so
/// lookup uses lastPathComponent only), else the ArtworkCache copy downloaded from
/// the manifest URL. Both lookups key on the URL/name, never on content, so a
/// changed image must ship under a new file name — see ArtworkCache.
enum ArtCache {
    private static let lock = NSLock()
    private static var images: [String: UIImage] = [:]
    private static var failures: Set<String> = []
    private static var inFlight: [String: Task<UIImage?, Never>] = [:]

    /// Synchronous accessor: non-nil only after a successful decode has been memoized.
    static func cached(forArt path: String) -> UIImage? {
        lock.lock()
        defer { lock.unlock() }
        return images[path]
    }

    /// Decode once per art path, off-main, memoized forever.
    static func uiImage(forArt path: String) async -> UIImage? {
        let pending: Task<UIImage?, Never>? = locked {
            if images[path] != nil || failures.contains(path) { return nil }
            if let task = inFlight[path] { return task }
            let task = Task<UIImage?, Never>.detached(priority: .userInitiated) {
                let result = await decode(artPath: path)
                locked {
                    if let result {
                        images[path] = result
                    } else {
                        failures.insert(path)
                    }
                    inFlight[path] = nil
                }
                return result
            }
            inFlight[path] = task
            return task
        }
        if let pending {
            return await pending.value
        }
        return locked { images[path] }
    }

    /// Fire-and-forget decodes for every game's art. Called at scene connect so the
    /// posters are ready at (or a beat after) first paint instead of popping in when
    /// each GameArt's .task gets around to them; those tasks then join the in-flight
    /// decode or hit the memo.
    static func prewarm(_ games: [Game]) {
        for game in games {
            guard let art = game.art else { continue }
            Task { _ = await uiImage(forArt: art) }
        }
    }

    private static func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    /// Decoded-bitmap ceiling. Cards render at most ~410pt wide (~1230px at 3x), so
    /// 720p covers every device. The bundled covers are encoded to exactly this
    /// (tools/encode_artwork.sh); the ceiling is what stops a larger one — served art,
    /// or a future master — from decoding at full size.
    private static let maxPixelSize = CGSize(width: 1280, height: 720)

    private static func decode(artPath: String) async -> UIImage? {
        if let data = bundledData(artPath: artPath) {
            return decode(data: data)
        }
        // Not shipped in this build — the served manifest introduced or
        // re-versioned it. Pull it through the URL-keyed disk cache.
        guard let url = remoteArtURL(artPath),
              let file = await ArtworkCache.fetch(url),
              let data = try? Data(contentsOf: file)
        else { return nil }
        return decode(data: data)
    }

    private static func bundledData(artPath: String) -> Data? {
        let file = (artPath as NSString).lastPathComponent
        let name = (file as NSString).deletingPathExtension
        let ext = (file as NSString).pathExtension
        guard
            !name.isEmpty,
            let url = Bundle.main.url(forResource: name, withExtension: ext.isEmpty ? nil : ext)
        else { return nil }
        return try? Data(contentsOf: url)
    }

    private static func decode(data: Data) -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }   // WebP decodes natively on iOS 17
        // UIImage(data:) only parses the header — without forcing it here, the
        // bitmap decode happens lazily inside the main thread's first CA commit,
        // defeating this off-main task. preparingThumbnail also downsamples
        // (aspect-preserving) in the same pass.
        if image.size.width > maxPixelSize.width || image.size.height > maxPixelSize.height,
           let thumbnail = image.preparingThumbnail(of: maxPixelSize) {
            return thumbnail
        }
        return image.preparingForDisplay() ?? image
    }
}

// MARK: - GameArt

/// Cover art for a game, or an accent-gradient fallback when art is missing / fails to decode.
struct GameArt: View {
    let game: Game

    @Environment(\.pbPalette) private var palette
    @State private var image: UIImage?
    @State private var decodeFailed = false

    init(game: Game) {
        self.game = game
        if let art = game.art {
            _image = State(initialValue: ArtCache.cached(forArt: art))
        }
    }

    var body: some View {
        Rectangle()
            .fill(palette.surfaceVariant)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if game.art == nil || decodeFailed {
                    fallbackGradient
                }
            }
            .clipped()
            .accessibilityLabel(game.name)
            // Not only while there is no image: a refreshed manifest can rename the art
            // under a card that keeps its identity.
            .task(id: game.art) {
                decodeFailed = false
                guard let art = game.art else { image = nil; return }
                if let cached = ArtCache.cached(forArt: art) { image = cached; return }
                image = await ArtCache.uiImage(forArt: art)
                decodeFailed = image == nil
            }
    }

    private var fallbackGradient: LinearGradient {
        LinearGradient(
            colors: [game.accentColor.opacity(0.50), game.accentColor.opacity(0.14)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - GameIcon

/// A game's square brand mark — the manifest `icon`, not the 16:9 cover (a poster crop is
/// unreadable this small). Falls back to the TV glyph for a game with no icon, or an
/// advert that resolved to an unknown launcher subdomain. The mark fills the tile and is
/// clipped to it: icons ship in their own app-icon frame (rounded square, own backdrop),
/// so a plate underneath would only show as a ring around a frame.
struct GameIcon: View {
    let game: Game
    let tint: Color

    @State private var image: UIImage?

    init(game: Game, tint: Color) {
        self.game = game
        self.tint = tint
        if let icon = game.icon {
            _image = State(initialValue: ArtCache.cached(forArt: icon))
        }
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Image(systemName: "tv")
                    .font(.system(size: 26))
                    .foregroundStyle(tint)
                    .frame(width: 48, height: 48)
            }
        }
        // Re-read on every icon change: a card slot can switch games under the same view
        // (the rejoin card going from one room to another), and keeping a loaded image
        // would show the previous game's icon.
        .task(id: game.icon) {
            guard let icon = game.icon else { image = nil; return }
            image = ArtCache.cached(forArt: icon)
            if image == nil { image = await ArtCache.uiImage(forArt: icon) }
        }
    }
}

// MARK: - StepRow

/// Numbered instruction row: 28pt solid-primary circle + attributed body text.
struct StepRow: View {
    let number: Int
    let text: AttributedString

    @Environment(\.pbPalette) private var palette

    init(number: Int, text: AttributedString) {
        self.number = number
        self.text = text
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                // Solid primary, not primaryContainer — the pale container tint is
                // nearly invisible against the sheet's surface in light mode.
                Circle()
                    .fill(palette.primary)
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(.pbLabelLarge)
                    .foregroundStyle(palette.onPrimary)
            }
            Text(text)
                .font(.pbBodyLarge)
                .foregroundStyle(palette.onSurface)
        }
    }
}

// MARK: - JoinButtons

/// The two join actions in one row: scan, and the keyboard for a typed code. The home dock
/// and a playable game's info sheet, so joining looks the same wherever it's offered.
struct JoinButtons: View {
    let onScan: () -> Void
    let onEnterCode: () -> Void

    @Environment(\.pbPalette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            ScanButton(action: onScan)
            Button(action: onEnterCode) {
                Image(systemName: "keyboard")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(palette.onSurface)
                    .frame(width: 30, height: 30)
            }
            .modifier(GhostCircleButton())
            .accessibilityLabel("Enter code manually")
        }
    }
}

/// A round glass button on iOS 26; the ghost button (the card fill with a 1.5pt line)
/// before. 56pt around the 30pt glyph, like the scan pill beside it. A modifier rather
/// than an inline `if #available` so the SDK-17 build compiles.
private struct GhostCircleButton: ViewModifier {
    @Environment(\.pbPalette) private var palette

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
        } else {
            content
                .buttonStyle(.plain)
                .padding(13)
                .background(palette.ghost, in: Circle())
                .overlay(Circle().strokeBorder(palette.ghostLine, lineWidth: 1.5))
        }
    }
}

// MARK: - ScanButton

/// The one primary action: scan. The lead of JoinButtons. The sunset
/// fills a screen's one primary button and nothing else; a 56pt pill, like Android's.
struct ScanButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Scan code", systemImage: "qrcode.viewfinder")
                .font(.pbTitleMedium)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
        }
        .modifier(SunsetButton())
    }
}

/// The primary action's fill, top to bottom.
let sunsetGradient = LinearGradient(colors: PBPalette.actionSunset, startPoint: .top, endPoint: .bottom)

/// The sunset laid over Liquid Glass where the OS has it (iOS 26): the gradient at 85%
/// over regular glass, so the glass still catches the light at the rim and the posters
/// move faintly through it; the filled pill painted with the gradient before. 56pt, like
/// Android's. A modifier rather than an inline `if #available` so the SDK-17 build
/// compiles.
private struct SunsetButton: ViewModifier {
    private let sunset = sunsetGradient

    func body(content: Content) -> some View {
        let pill = content
            .buttonStyle(.plain)
            .padding(.vertical, 13)
        if #available(iOS 26.0, *) {
            pill
                .background(sunset.opacity(0.85), in: Capsule())
                .glassEffect(.regular.interactive(), in: Capsule())
        } else {
            pill.background(sunset, in: Capsule())
        }
    }
}

// MARK: - SecondaryButton

/// The secondary action beside the one sunset primary: the system bordered button,
/// which inherits the global ink tint, sized to match the primary.
struct SecondaryButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: action) {
            label()
                .font(.pbTitleMedium)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}

// MARK: - StatusTag

/// A quiet tint beside a game's name: amber for Beta, the chip grey for Coming soon. A
/// live game has no tag at all. Used by the home cards.
struct StatusTag: View {
    let game: Game

    @Environment(\.pbPalette) private var palette

    var body: some View {
        if !game.isPlayable || game.isBeta {
            let ink = game.isBeta ? palette.onBetaTag : palette.onSurfaceVariant
            Text(game.isBeta ? LocalizedStringKey("Beta") : "Coming soon")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(game.isBeta ? palette.betaTag : palette.surfaceVariant))
        }
    }
}

// MARK: - PressableCardButtonStyle

/// Card press micro-interaction: spring scale to 0.97 while pressed.
struct PressableCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - AppSheetContainer

/// House-style sheet: opens fully expanded at its content height, no grabber,
/// 28pt corners, the cards' glass (`SheetBackground`).
struct AppSheetContainer<Content: View>: View {
    @State private var measuredHeight: CGFloat = 0
    /// A game's theme-color, used as the sheet surface so an in-game sheet reads as
    /// part of the game. Nil (the default) keeps the glass. Callers pick the
    /// light or dark palette to match it, so the sheet's text stays legible.
    private let surfaceTint: Color?
    private let content: () -> Content

    init(surfaceTint: Color? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.surfaceTint = surfaceTint
        self.content = content
    }

    var body: some View {
        // The ScrollView engages only when the detent gets clamped below the
        // content height (small displays, large text) — .basedOnSize keeps a
        // fitting sheet from bouncing.
        ScrollView {
            content()
                .frame(maxWidth: .infinity, alignment: .top)
                // Take the content's IDEAL height: the first layout runs at the
                // .medium placeholder, and without this the compressed first layout
                // (truncated text, collapsed aspect-ratio views) self-consistently
                // measures as the final height.
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    measuredHeight = height
                }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Placeholder until the first measurement, which lands after the slide-up
        // starts. It must be a full-size detent: iOS 26 animates a tiny one out of the
        // bottom-left corner.
        .presentationDetents([measuredHeight > 0 ? .height(fittedHeight) : .custom(PlaceholderDetent.self)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(28)
        .modifier(SheetBackground(surfaceTint: surfaceTint))
        // Each presentation decides its own bars.
        .modifier(HorizontalBars())
    }

    /// The content's height, or on the iPhone Duo all the height there is when the content
    /// nearly fills it: below full height iOS 27.1 draws the status bar into the sheet's
    /// corner on its cover screen, whatever the app asks for (`HorizontalBars`).
    /// Other iPhones keep a sheet as tall as its content, with home showing above it.
    private var fittedHeight: CGFloat {
        let full = PlaceholderDetent.fullHeight
        return RootHostingController.hasHinge && full > 0 && measuredHeight > full - Self.nearlyFull
            ? full : measuredHeight
    }

    /// How near the full height counts as filling it: on the Duo's cover screen a full sheet
    /// gives the status bar its strip across the top back, and a bottom padding on top.
    private static var nearlyFull: CGFloat { 100 }
}

/// Half the height, as `.medium`, while the content is measured — and where the sheet
/// learns its full height, which only a custom detent is told. A static: one app sheet is
/// up at a time, and each opens on this placeholder.
private struct PlaceholderDetent: CustomPresentationDetent {
    nonisolated(unsafe) static var fullHeight: CGFloat = 0

    static func height(in context: Context) -> CGFloat? {
        fullHeight = context.maxDetentValue
        return context.maxDetentValue / 2
    }
}

/// Keeps the status bar and the bar buttons across the top on the iPhone Duo, where iOS
/// 27.1 otherwise moves them into a vertical bar down the side — the launcher is drawn for
/// a phone's top bars. Every presentation decides its own bars, so each one carries this,
/// and the bar never jumps between the side and the top as sheets open (Apple asks for a
/// stable choice). A modifier rather than an inline `if #available` so the SDK-17 build
/// compiles.
struct HorizontalBars: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.toolbarVerticalBehavior(.disabled)
        } else {
            content
        }
    }
}

private struct WideSheetCard<Content: View>: View {
    let width: CGFloat
    let close: () -> Void
    @ViewBuilder let content: Content

    /// How far a swipe has pulled the card down.
    @State private var pull: CGFloat = 0

    @Environment(\.pbPalette) private var palette

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(perform: close)
                .accessibilityHidden(true)
            content
                .frame(width: width)
                .background { glass }
                .offset(y: pull)
                .gesture(DragGesture()
                    .onChanged { pull = max($0.translation.height, 0) }
                    .onEnded { drag in
                        // A fling or a long pull closes it; anything less springs back.
                        if drag.predictedEndTranslation.height > 160 {
                            close()
                        } else {
                            withAnimation(.spring(duration: 0.3)) { pull = 0 }
                        }
                    })
                // Floats a little above the edge, as iOS's sheets do.
                .padding(.bottom, 8)
                .accessibilityAction(.escape, close)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder private var glass: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        if #available(iOS 26.0, *) {
            Color.clear.glassEffect(.regular.tint(palette.sheetGlass[0].opacity(0.85)), in: shape)
        } else {
            shape.fill(LinearGradient(colors: palette.sheetGlass, startPoint: .top, endPoint: .bottom))
        }
    }
}

/// The sheet's own fill when a caller gives one; otherwise the cards' glass: on iOS 26
/// Liquid Glass tinted 85% with the sheet glass's colour (any thinner and the home shows
/// through busily), the drawn sheet glass before. A modifier rather than an inline
/// `if #available` so the SDK-17 build compiles.
private struct SheetBackground: ViewModifier {
    let surfaceTint: Color?

    @Environment(\.pbPalette) private var palette

    func body(content: Content) -> some View {
        if let surfaceTint {
            content.presentationBackground(surfaceTint)
        } else if #available(iOS 26.0, *) {
            content.presentationBackground {
                Color.clear.glassEffect(.regular.tint(palette.sheetGlass[0].opacity(0.85)), in: Rectangle())
            }
        } else {
            content.presentationBackground(LinearGradient(colors: palette.sheetGlass, startPoint: .top, endPoint: .bottom))
        }
    }
}

extension View {
    /// An app sheet as a card of our own, `width` wide: on the open Duo held as a book iOS
    /// keeps a real sheet about a portrait phone wide, whatever size it is asked for. It
    /// rises from the bottom over home like one, on the same glass, and a tap beside it,
    /// a swipe down or the escape gesture closes it.
    func wideSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        width: CGFloat,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        fullScreenCover(item: item, onDismiss: onDismiss) { value in
            WideSheetCard(width: width, close: { item.wrappedValue = nil }) { content(value) }
                .presentationBackground(.clear)
                .modifier(HorizontalBars())
        }
    }

    func appSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        surfaceTint: Color? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        sheet(item: item, onDismiss: onDismiss) { item in
            AppSheetContainer(surfaceTint: surfaceTint) { content(item) }
        }
    }
}
