import SwiftUI
import AVFoundation

// MARK: - GameInfoSheet

struct GameInfoSheet: View {
    let game: Game
    /// Home is landscape — on the open iPhone Duo held as a book, the only place it turns,
    /// where this shows on a wide card rather than a sheet (MainScreen). Its own size
    /// classes don't tell: a sheet there is compact wide and regular tall.
    let landscape: Bool
    let onScan: () -> Void
    let onEnterCode: () -> Void

    @Environment(\.pbPalette) private var palette

    init(game: Game, landscape: Bool, onScan: @escaping () -> Void, onEnterCode: @escaping () -> Void) {
        self.game = game
        self.landscape = landscape
        self.onScan = onScan
        self.onEnterCode = onEnterCode
    }

    var body: some View {
        Group {
            if landscape {
                // The phone's stack is too tall for the screen, so the trailer goes
                // beside one column holding the rest, half and half, on a card wider
                // than iOS's sheet (wideSheet).
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 14) {
                        header
                        media
                    }
                    .frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 14) {
                        chips
                        play
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    media
                    chips
                    play
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 24)
        // The sheet adds the home indicator's room below this already. More left the Duo's
        // cover screen 10pt short, scrolling a sheet whose content all showed.
        .padding(.bottom, 12)
    }

    private var header: some View {
        HStack {
            Text(game.name)
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.onSurface)
            Spacer()
            if let range = game.playersRange {
                playersChip(range)
            }
        }
    }

    // A game with a trailer shows its gameplay loop, muted until the user
    // unmutes it; one without shows its cover art instead.
    private var media: some View {
        Group {
            if game.video != nil {
                GameplayLoopView(game: game)
            } else {
                GameArt(game: game)
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder private var chips: some View {
        if !game.tvApps.isEmpty || game.displayHost != nil {
            PlatformChips(game: game, stacked: landscape)
        }
    }

    // The app is the controller, so a first-timer who taps the card
    // learns they need the game running on a big screen first — then can
    // act right here. Deliberately path-free ("start it", not "open the
    // app / the site") — where the game runs is the platform-chip row's
    // job (PlatformChips).
    @ViewBuilder private var play: some View {
        if game.isPlayable {
            VStack(alignment: .leading, spacing: 16) {
                StepRow(number: 1, text: AttributedString(
                    String(format: String(localized: "Start %@ on your TV."), game.name)))
                StepRow(number: 2, text: AttributedString(
                    String(localized: "Scan the room code it shows.")))
            }
            .padding(.vertical, 4)
            JoinButtons(onScan: onScan, onEnterCode: onEnterCode)
        }
    }

    // "1–8" + person glyph, plain like the site's card meta: the glyph stands in for
    // the word "players", so the count range needs no translation (Game.playersRange).
    private func playersChip(_ range: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.onSurfaceVariant)
            Text(range)
                .font(.pbLabelLarge)
                .foregroundStyle(palette.onSurface)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 5)
    }
}

// MARK: - PlatformChips

/// Platforms with native TV apps (manifest tvApps): id -> the nearby-card device label,
/// reused. Unknown manifest ids simply have no chip (and no home-card mention).
let tvPlatforms: [(String, LocalizedStringResource)] = [
    ("appletv", "Apple TV"),
    ("androidtv", "Android TV"),
]

/// The one TV platform whose store this app links: the App Store installs an Apple TV app
/// from the iPhone (onto the TV with Automatically Install Apps, else into its Purchased
/// list), and App Review 2.3.10 bars pointing at another platform's store. Android links
/// androidtv.
private let ownStorePlatform = "appletv"

/// Where the game runs, as a row of equal chips (or, `stacked`, a column of rows): one per
/// declared TV app plus one for the browser path. A chip with somewhere to go is itself the
/// button, marked by a corner glyph: this app's own store once that TV app is live
/// (manifest tvStores), the share sheet for the game's address. A not-yet-live TV app is a
/// dimmed chip tagged "Soon".
/// This row is the sheet's only mention of platforms and host, so the play steps stay
/// path-free.
///
/// Deliberately no brand logos: Apple licenses only its word marks to third
/// parties, and Google's Android TV guidance excludes the robot — the neutral
/// TV glyph + name is the compliant version of the same message (Android
/// matches).
private struct PlatformChips: View {
    let game: Game
    let stacked: Bool

    @Environment(\.pbPalette) private var palette
    @Environment(\.openURL) private var openURL

    var body: some View {
        let layout = stacked ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 9))
        layout {
            ForEach(tvPlatforms, id: \.0) { id, name in
                if let status = game.tvApps[id] {
                    tvChip(id: id, label: String(localized: name), live: status == "live")
                }
            }
            if let url = game.controllerBaseUrl.flatMap(URL.init(string:)), let host = game.displayHost {
                // The zero-width space before each dot is an invisible break hint:
                // a narrow chip wraps to "hexstacker" / ".com" instead of truncating.
                ShareLink(item: url) {
                    chip(icon: "globe", label: host.replacingOccurrences(of: ".", with: "\u{200B}."))
                }
                .buttonStyle(.plain)
                .modifier(ChipSurface(interactive: true))
                .overlay(alignment: markCorner) { cornerGlyph("square.and.arrow.up") }
                .accessibilityLabel(String(format: String(localized: "Share %@"), host))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func tvChip(id: String, label: String, live: Bool) -> some View {
        if !live {
            chip(icon: "tv", label: label, dimmed: true)
                .modifier(ChipSurface(interactive: false))
                .overlay(alignment: markCorner) { soonTag }
                .accessibilityElement(children: .combine)
        } else if id == ownStorePlatform, let store = game.tvStores[id].flatMap(URL.init(string:)) {
            Button { openURL(store) } label: { chip(icon: "tv", label: label) }
                .buttonStyle(.plain)
                .modifier(ChipSurface(interactive: true))
                .overlay(alignment: markCorner) { cornerGlyph("arrow.up.right") }
                .accessibilityHint(String(localized: "Get the TV app"))
        } else {
            chip(icon: "tv", label: label)
                .modifier(ChipSurface(interactive: false))
        }
    }

    // `dimmed`: icon and label at 45% — the not-yet-live state the poster's "Coming
    // soon" chip marks.
    @ViewBuilder
    private func chip(icon: String, label: String, dimmed: Bool = false) -> some View {
        let content = dimmed ? palette.onSurface.opacity(0.45) : palette.onSurface
        let glyph = Image(systemName: icon)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(content)
        let name = Text(label)
            .font(.pbLabelMedium)
            .foregroundStyle(content)
        Group {
            if stacked {
                // The end of the row is kept for the mark.
                HStack(spacing: 10) {
                    glyph
                    name.lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 12)
                .padding(.leading, 16)
                .padding(.trailing, 44)
            } else {
                VStack(spacing: 6) {
                    glyph
                    name.multilineTextAlignment(.center).lineLimit(2)
                }
                // Top-aligned so icons and names line up across chips when one name wraps.
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.vertical, 12)
                .padding(.horizontal, 6)
            }
        }
        // The whole chip takes the tap, not just its glyph and text.
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// Where a chip's mark sits: its top corner, or a row's end.
    private var markCorner: Alignment { stacked ? .trailing : .topTrailing }

    // Marks a chip as a button. Taps pass through to the chip under it.
    private func cornerGlyph(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(palette.onSurfaceVariant)
            .padding(stacked ? 16 : 9)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // Across a chip's top edge (inside the chip it covered the TV glyph); at a row's end.
    private var soonTag: some View {
        Text(String(localized: "Soon"))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(palette.onSurfaceVariant)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(palette.surfaceVariant))
            .offset(x: stacked ? -12 : 4, y: stacked ? 0 : -6)
    }
}

/// A chip's ground: Liquid Glass on iOS 26, reacting to touch only on a chip that is a
/// button; the sheet's highest fill below iOS 26. Glass goes on the chip itself rather than
/// through `.buttonStyle(.glass)`, whose padding wrapped the address onto two lines.
private struct ChipSurface: ViewModifier {
    let interactive: Bool

    @Environment(\.pbPalette) private var palette

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        if #available(iOS 26.0, *) {
            content.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            // Highest: the step that shows on the sheet's glass (SheetBackground).
            content.background(shape.fill(palette.surfaceContainerHighest))
        }
    }
}

// MARK: - GameplayLoopView

/// A gameplay loop, fetched to cache on demand (TrailerCache) and played from
/// disk. Cover art fills the slot immediately; the player sits on top and stays
/// transparent until its first frame is ready, then fades in over the art.
///
/// Every open starts muted; a clip with an audio track gets a mute toggle. A tap
/// plays the clip fullscreen (TrailerFullscreenView), pausing this one meanwhile.
/// Android matches throughout.
struct GameplayLoopView: View {
    let game: Game

    @State private var localURL: URL?
    @State private var hasAudio = false
    @State private var muted = true
    @State private var progress: Double?
    @State private var fullscreen = false
    /// Where the fullscreen clip was left — the inline loop picks up there.
    @State private var resumeAt = CMTime.zero
    /// Window coordinates — where the fullscreen clip grows from and shrinks back to.
    @State private var frame: CGRect = .zero

    var body: some View {
        ZStack {
            GameArt(game: game)
            if let localURL {
                LoopingPlayerView(url: localURL, muted: muted, paused: fullscreen, resumeAt: resumeAt)
                    .contentShape(Rectangle())
                    // No cover animation: TrailerFullscreenView animates itself.
                    .onTapGesture { withTransaction(\.disablesAnimations, true) { fullscreen = true } }
                    .accessibilityElement()
                    .accessibilityLabel(String(localized: "Play fullscreen"))
                    .accessibilityAddTraits(.isButton)
            }
        }
        // A download in flight — never shown for a cached clip. Stays full from the
        // last byte until the player takes over. Inset as a pill on its own track,
        // clear of the rounded corners.
        .overlay(alignment: .bottom) {
            if let progress, localURL == nil {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.black.opacity(0.35))
                        Capsule().fill(Color.white.opacity(0.9)).frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
            }
        }
        // The symbol shows the state, the label names the action.
        .overlay(alignment: .topTrailing) {
            if hasAudio {
                Button {
                    muted.toggle()
                    // Unmuting is a request to hear it, so take the game category:
                    // audible through the silent switch, mixed over the user's music.
                    if !muted { GameAudioSession.configureOnce() }
                } label: {
                    Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.35), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(muted ? String(localized: "Unmute") : String(localized: "Mute"))
                .padding(8)
            }
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
        .fullScreenCover(isPresented: $fullscreen) {
            if let localURL {
                TrailerFullscreenView(url: localURL, source: frame) { time in
                    resumeAt = time
                    withTransaction(\.disablesAnimations, true) { fullscreen = false }
                }
                .presentationBackground(.clear)
                .modifier(HorizontalBars())
            }
        }
        .task {
            guard localURL == nil,
                  let remote = game.video.flatMap(URL.init(string:)) else { return }
            // Before any player exists: a muted AVPlayer still activates the shared
            // audio session, and the default category would stop the player's music.
            await GameAudioSession.configureForMutedTrailer()
            // Starts no sooner than 0.6s after the sheet opens, cached or not, so the
            // clip never starts under the sheet's slide-in. Any longer reads as loading.
            async let fetched = TrailerCache.fetch(remote) { fraction in
                Task { @MainActor in progress = fraction }
            }
            try? await Task.sleep(for: .seconds(0.6))
            guard let local = await fetched else { return }
            hasAudio = (try? await AVURLAsset(url: local).loadTracks(withMediaType: .audio))?.isEmpty == false
            localURL = local
        }
    }
}

// MARK: - TrailerFullscreenView

/// The clip fullscreen in landscape, with sound, played once from the start —
/// closing itself at the end. Unlike the inline loop it interrupts the user's
/// audio while it plays (GameAudioSession.beginFullscreenTrailer).
///
/// Landscape is drawn, not rotated into: the interface stays portrait and the clip
/// grows out of the inline loop's `source` frame while turning 90° toward the side
/// the phone is held, and shrinks back into it on close. Turning the window instead
/// can only start once the cover is up and undo once it is gone, so opening and
/// closing each played as a portrait step and then a rotation.
private struct TrailerFullscreenView: View {
    let url: URL
    let source: CGRect
    /// Dismisses the cover without its own animation, once the clip is back in place,
    /// with where the clip got to — zero once it played to the end.
    let close: (CMTime) -> Void

    @State private var player: AVPlayer?
    @State private var expanded = false
    /// The session hand-back, started once by whichever way the cover goes.
    @State private var sessionEnded: Task<Void, Never>?
    @State private var angle = TrailerFullscreenView.landscapeAngle(keeping: .degrees(90))

    private static let morph = Animation.spring(duration: 0.45, bounce: 0.1)

    /// Clockwise turn that stands the content upright for how the device is held;
    /// portrait or flat keeps `current`.
    private static func landscapeAngle(keeping current: Angle) -> Angle {
        switch UIDevice.current.orientation {
        case .landscapeLeft: .degrees(90)
        case .landscapeRight: .degrees(-90)
        default: current
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(expanded ? 1 : 0)
                video
                    .frame(width: expanded ? geo.size.height : source.width,
                           height: expanded ? geo.size.width : source.height)
                    .clipShape(RoundedRectangle(cornerRadius: expanded ? 0 : 16))
                    .rotationEffect(expanded ? angle : .zero)
                    .position(expanded ? CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                                       : CGPoint(x: source.midX, y: source.midY))
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            withAnimation(Self.morph) { expanded = true }
        }
        .onDisappear {
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
            endSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.3)) { angle = Self.landscapeAngle(keeping: angle) }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification)) { note in
            if let item = note.object as? AVPlayerItem, item === player?.currentItem { collapse(at: .zero) }
        }
        .task {
            // The player exists from the start of the grow so its first frame is ready
            // to show; only playback waits for the session, which can queue behind the
            // previous close's (slow) deactivation.
            let player = AVPlayer(url: url)
            self.player = player
            await GameAudioSession.beginFullscreenTrailer()
            player.play()
        }
    }

    /// The hand-back runs alongside the shrink, and the cover — on whose dismissal
    /// the inline loop resumes — goes only once it is done.
    private func collapse(at time: CMTime) {
        guard expanded else { return }
        endSession()
        withAnimation(Self.morph) { expanded = false } completion: {
            Task {
                await sessionEnded?.value
                close(time)
            }
        }
    }

    private func endSession() {
        guard sessionEnded == nil else { return }
        player?.pause()
        sessionEnded = Task { await GameAudioSession.endFullscreenTrailer() }
    }

    private var video: some View {
        ZStack {
            if let player {
                // The X sits on the video's corner rather than the screen's, where it
                // would straddle the pillarbox edge on a wider screen.
                PlayerLayerView(player: player)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .overlay(alignment: .topLeading) {
                        Button { collapse(at: player.currentTime()) } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.35), in: Circle())
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(localized: "Close video"))
                        .padding(12)
                        .opacity(expanded ? 1 : 0)
                    }
            }
        }
    }
}

private struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerUIView {
        let view = PlayerLayerUIView()
        view.playerLayer.player = player
        view.fadeInWhenReady()
        return view
    }

    func updateUIView(_ uiView: PlayerLayerUIView, context: Context) {}
}

/// A view whose backing layer is an AVPlayerLayer, so it resizes with the view.
private class PlayerLayerUIView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    private var readyObservation: NSKeyValueObservation?

    /// Hidden until the first frame is ready, then faded in over whatever is beneath:
    /// the art inline (Android fades the art out at the same moment), the black
    /// backdrop while the fullscreen clip grows.
    func fadeInWhenReady() {
        alpha = 0
        readyObservation = playerLayer.observe(\.isReadyForDisplay) { [weak self] layer, _ in
            guard layer.isReadyForDisplay else { return }
            Task { @MainActor in
                UIView.animate(withDuration: 0.3) { self?.alpha = 1 }
            }
        }
    }
}

// MARK: - Looping player (private)

private struct LoopingPlayerView: UIViewRepresentable {
    let url: URL
    let muted: Bool
    let paused: Bool
    let resumeAt: CMTime

    final class PlayerUIView: PlayerLayerUIView {
        private var player: AVQueuePlayer?
        private var looper: AVPlayerLooper?
        private var wasPaused = false

        func configure(url: URL, muted: Bool) {
            guard player == nil else { return }
            let item = AVPlayerItem(url: url)
            let queuePlayer = AVQueuePlayer()
            queuePlayer.isMuted = muted
            looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
            player = queuePlayer
            playerLayer.player = queuePlayer
            playerLayer.videoGravity = .resizeAspectFill
            fadeInWhenReady()
            queuePlayer.play()
        }

        /// Coming out of a pause, picks up at the keyframe nearest `resumeAt`: instant,
        /// where an exact seek first decodes up to seconds of frames (the trailers'
        /// keyframes are ~4s apart) — and a loop hides the difference.
        func update(muted: Bool, paused: Bool, resumeAt: CMTime) {
            player?.isMuted = muted
            if paused {
                player?.pause()
            } else {
                if wasPaused {
                    player?.seek(to: resumeAt, toleranceBefore: .positiveInfinity,
                                 toleranceAfter: .positiveInfinity)
                }
                player?.play()
            }
            wasPaused = paused
        }

        func teardown() {
            player?.pause()
            playerLayer.player = nil
            looper?.disableLooping()
            looper = nil
            player = nil
        }
    }

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.configure(url: url, muted: muted)
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.update(muted: muted, paused: paused, resumeAt: resumeAt)
    }

    static func dismantleUIView(_ uiView: PlayerUIView, coordinator: ()) {
        uiView.teardown()
    }
}
