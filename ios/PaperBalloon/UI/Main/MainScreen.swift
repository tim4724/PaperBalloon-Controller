import SwiftUI
import UIKit

// MARK: - MainScreen (home / launcher)

struct MainScreen: View {
    let deepLink: String?
    /// True while this screen is the visible top of the stack. Drives the rejoin
    /// poll: onAppear does NOT re-fire on NavigationStack pop-back, and scenePhase
    /// proved unreliable as a task trigger here (stuck .inactive at launch), so the
    /// router's path emptiness is the signal — mirroring Android's STARTED gating.
    let isTopVisible: Bool
    let onDeepLinkConsumed: () -> Void
    let onJoin: (String, String, [String]) -> Void   // (joinUrl, title, allowedHosts)
    let onOpenLegalDoc: (String) -> Void
    let onOpenAbout: () -> Void

    init(deepLink: String?, isTopVisible: Bool, onDeepLinkConsumed: @escaping () -> Void,
         onJoin: @escaping (String, String, [String]) -> Void,
         onOpenLegalDoc: @escaping (String) -> Void,
         onOpenAbout: @escaping () -> Void) {
        self.deepLink = deepLink
        self.isTopVisible = isTopVisible
        self.onDeepLinkConsumed = onDeepLinkConsumed
        self.onJoin = onJoin
        self.onOpenLegalDoc = onOpenLegalDoc
        self.onOpenAbout = onOpenAbout
    }

    // MARK: State

    // Seeded synchronously (cached fetch, else bundled); the once-per-launch
    // refresh task below updates it live when the served manifest differs.
    @ObservedObject private var manifest = ManifestStore.shared
    private var games: [Game] { manifest.games }
    // Rooms advertised on the LAN by native display apps (contract §8). Browsed only
    // while this screen is the visible top; resolved against `games` on every render,
    // so a manifest refresh re-admits (or drops) an advert without restarting anything.
    @StateObject private var nearby = NearbyBrowser()
    // Whether a network mDNS could traverse — Wi-Fi or Ethernet — is up at all. Only
    // picks the status line's wording — browsing keeps running regardless (see
    // LanMonitor on the hotspot case).
    @StateObject private var lan = LanMonitor()
    @State private var lanAsked = LocalNetworkAsked.isSet
    /// mDNS discovery never "completes" — it just keeps listening — so a spinner would
    /// spin forever with the TV off. Settle to a plain "not found" after a grace period.
    @State private var nearbySearchSettled = false
    /// An advertised code becomes a card only once the relay has resolved it — that call
    /// is what supplies the join URL, `pbp` and the occupancy check.
    @State private var resolvedNearby: [String: NearbyRoom] = [:]
    // A record that stops appearing doesn't end a room — only the relay does, and a
    // held room keeps being probed until it answers (see AdvertLinger).
    @State private var linger = AdvertLinger()
    @State private var profile: Profile = ProfileStore.load()
    // Item-based presentation: values are snapshotted into the request at
    // present time. @State read inside a sheet/cover content closure is not
    // dependency-tracked and can be stale (verified on-device), so the sheets
    // must receive their inputs through the item.
    @State private var profileRequest: ProfileSheetRequest? = nil
    @State private var afterName: AfterName? = nil
    @State private var showCodeEntry = false
    @State private var codeText = ""
    // A join being resolved: the directory probe a scan, link or typed code takes can
    // cost a round trip, and the cover below is the only sign the tap landed.
    @State private var joining = false
    @State private var codeError: String? = nil
    @State private var scanRequest: ScanRequest? = nil
    @State private var rejoin: RecentRoom? = nil
    @State private var infoGame: Game? = nil
    // A scan/enter action tapped inside the info sheet, run once it dismisses.
    @State private var pendingSheetAction: AfterName? = nil
    // Haptic triggers (any change fires the paired sensoryFeedback).
    @State private var successTick = 0
    @State private var errorTick = 0

    @Environment(MessageCenter.self) private var messages
    @Environment(\.pbPalette) private var palette

    // MARK: Body

    var body: some View {
        ZStack(alignment: .bottom) {
            palette.background.ignoresSafeArea()

            ScrollView {
                // One rhythm for the whole stack: the banner, every room card and every
                // poster are cards in a single list, so they all sit 12 apart. The one
                // real break is rooms-you-can-enter → the catalog, padded for below.
                VStack(spacing: 12) {
                    // The game-end notice sits atop the content, above the rejoin card
                    // (present only while the room is alive) — a high-contrast strip
                    // where the player's eye already is, not a bottom overlay.
                    if let banner = messages.gameEndBanner {
                        GameEndBanner(message: banner) { messages.dismissGameEndBanner() }
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // The rejoin room's own advertisement folds INTO the rejoin card, name
                    // and all, rather than standing up a second card for the room the
                    // player is already being offered.
                    let home = homeRooms(Array(resolvedNearby.values), rejoin: rejoin)
                    if let rejoin {
                        RejoinCard(room: rejoin, advert: home.rejoinAdvert) {
                            resolveAndJoin(rejoin.joinUrl)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }

                    // "Searching…" / "No rooms found" are claims about having looked and
                    // come up empty — false while a room card is already on screen, rejoin
                    // included. The ask is an offer rather than a claim, so it stays
                    // regardless: hiding it behind a rejoin card would make discovery
                    // invisible for the rest of the session. So does the denied button,
                    // which is the same offer by another route.
                    // A clip can't browse (no Bonjour), so it makes no claim either way.
                    if !PB.isAppClip, nearbyState == .ask || nearbyState == .denied
                        || (home.nearby.isEmpty && rejoin == nil) {
                        NearbyStatusCard(
                            state: nearbyState,
                            onAsk: {
                                LocalNetworkAsked.set()
                                lanAsked = true
                                nearby.start()
                            },
                            onOpenSettings: {
                                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                                UIApplication.shared.open(url)
                            }
                        )
                        .transition(.opacity)
                    }
                    ForEach(home.nearby) { room in
                        NearbyCard(room: room) { requireName(.join(room.target)) }
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }

                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Games")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(palette.onSurface)
                            // Path-free: on a TV the game is an app, on a laptop a website.
                            Text("Start a game on your TV or in your browser.")
                                .font(.pbBodyLarge)
                                .foregroundStyle(palette.onSurfaceVariant)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(games) { game in
                            GameCard(game: game) { infoGame = game }
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
                .background(alignment: .top) { SkyBackdrop() }
                .animation(.spring(duration: 0.45), value: messages.gameEndBanner)
                .animation(.spring(duration: 0.45), value: resolvedNearby.count)
            }
            // The dock sits in a bar at the bottom edge: the list scrolls under it and
            // blurs out into the soft scroll edge (the system's, on iOS 26), and the
            // content is inset so the last card stays reachable.
            .modifier(DockBar {
                JoinDock(
                    onScan: { requireName(.scan) },
                    onEnterCode: { requireName(.enterCode) }
                )
                .padding(.horizontal, 16)
                // The safe area already clears the home indicator — anything more
                // reads as a floating gap.
                .padding(.bottom, 4)
            })

            // The same cover the game host shows while the controller paints, so a join
            // is ONE loading screen from tap to page: this one names no game because
            // resolving is what discovers which one, and the host's picks up the name.
            if joining {
                JoiningCover(message: String(localized: "Joining…"),
                             background: palette.surface,
                             foreground: palette.onSurfaceVariant)
                    .transition(.opacity)
            }
        }
        .navigationTitle("Paper Balloon")
        // The join cover is full-screen; the toolbar pills would otherwise float over it
        // (Android's top bar scrolls inside the content, so it's covered for free).
        .toolbar(joining ? .hidden : .visible, for: .navigationBar)
        // "Controller" subtitle under the app name, matching Android's HomeTopBar.
        // Native subtitle slot is iOS 26+; on earlier releases the bar shows the
        // title alone (no subtitle affordance existed pre-26).
        .modifier(HomeNavigationSubtitle())
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            // The name capsule and the About button are unrelated actions, so they
            // read as two distinct glass pills rather than one merged container. On
            // iOS 26 a ToolbarSpacer(.fixed) is what splits the shared glass into two
            // pills with the system's standard gap — and the system keeps them the
            // same height (the icon-only About item becomes a circle on its own).
            // Labels are .primary (scheme-adaptive) so the glass legibility flip works
            // over poster art.
            ToolbarItem(placement: .topBarTrailing) {
                chipButton()
            }
            if #available(iOS 26.0, *) {
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
            }
            ToolbarItem(placement: .topBarTrailing) {
                aboutButton()
            }
        }
        .sensoryFeedback(.success, trigger: successTick)
        .sensoryFeedback(.error, trigger: errorTick)
        .ignoresSafeArea(.keyboard)
        .onChange(of: deepLink, initial: true) { _, newValue in
            guard let link = newValue else { return }
            // The router already popped to Main — clear anything presented over it,
            // or the cover/sheet would sit on top of the game host this link pushes.
            scanRequest = nil
            infoGame = nil
            profileRequest = nil
            pendingSheetAction = nil
            afterName = nil
            showCodeEntry = false
            // A legal-page App Link opens the in-app doc viewer; anything else is a
            // join. The URL keeps its locale segment (/en/privacy vs /privacy), so
            // the viewer loads the right variant. Except in the clip, a link that names
            // no room: a clip opens for every URL under an experience's prefix, and
            // Apple's own App Clip link names no room at all — those just show home.
            // (The app never sees one: its Universal Links are AASA-scoped to room paths.)
            let firstSegment = URLComponents(string: link)?.path.split(separator: "/").first.map(String.init)
            if PB.legalTitle(for: URL(string: link)) != nil {
                onOpenLegalDoc(link)
            } else if PB.isAppClip, !validRoomCode(firstSegment ?? "") {
                // Home is already showing.
            } else {
                resolveAndJoin(link)
            }
            onDeepLinkConsumed()
        }
        .onChange(of: codeText) { _, newValue in
            if newValue.count > 16 {
                codeText = String(newValue.prefix(16))
            }
        }
        .task(id: isTopVisible) {
            guard isTopVisible else { return }
            await runRejoinPoll()
        }
        // Browse only while home is on screen AND Local Network has been asked — the same
        // gating as the rejoin poll, and it keeps the Local Network prompt off the
        // game host and off a first launch nobody asked anything of yet.
        .onChange(of: isTopVisible, initial: true) { _, visible in
            if visible {
                // Re-read the profile on pop-back: a rename inside the game host writes
                // the store, and home's chip — and the next game's name — must follow.
                // (Android gets this for free: its Main entry is disposed under the game
                // host, so the remembered load re-runs on return.)
                profile = ProfileStore.load()
                // And the ask: a first join may have shown the prompt meanwhile.
                lanAsked = LocalNetworkAsked.isSet
            }
            if visible && lanAsked { nearby.start() } else { nearby.stop() }
            // Unlike the browser, not gated on the ask: watching the path is
            // passive, and the ask button costs nothing to leave un-hinted.
            if visible { lan.start() } else { lan.stop() }
        }
        // Re-checked on the same cadence as the rejoin card: both promise "you can enter
        // this", so both have to notice when the room dies or fills. Tied to the browse
        // task's lifetime, so nothing polls while this screen isn't the visible top.
        .task(id: nearby.adverts) {
            while !Task.isCancelled {
                // One probe per ROOM, not per record: a room announced by its display
                // and by every phone in it is still one code.
                let adverts = linger.hold(distinctAdverts(nearby.adverts))
                resolvedNearby = resolvedNearby.filter { key, _ in
                    adverts.contains { $0.code == key }
                }
                await withTaskGroup(of: (String, NearbyRoom?).self) { group in
                    for advert in adverts {
                        group.addTask { (advert.code, await resolveNearby(advert, games: games)) }
                    }
                    for await (code, room) in group {
                        if let room { resolvedNearby[code] = room } else { resolvedNearby[code] = nil }
                    }
                }
                do { try await Task.sleep(for: roomPollInterval) } catch { return }
            }
        }
        // Keyed on the LAN too: Wi-Fi coming back restarts the grace period, so the slot
        // reads "Searching…" again instead of a stale instant "No rooms found".
        .task(id: [lanAsked, lan.hasLan]) {
            nearbySearchSettled = false
            guard lanAsked else { return }
            try? await Task.sleep(for: .seconds(8))
            nearbySearchSettled = true
        }
        // Pull the served manifest once per launch (ManifestStore guards
        // re-entry, so push/pop re-creating this screen doesn't refetch).
        .task { await manifest.refresh() }
        .onChange(of: messages.gameEndBanner) { _, banner in
            // A just-ended game (banner appeared) may have cleared the saved room — a
            // room_not_found end drops it. Drop the card the instant the banner lands
            // rather than letting it linger up to a poll tick. Only ever clears: a card
            // is put up by a confirming probe and nothing else. (Android needs no
            // counterpart — its Main entry is disposed under the game host, so it comes
            // back with an empty slot anyway.)
            if banner != nil, RecentRoomStore.current() == nil {
                withAnimation(.spring(duration: 0.45)) { rejoin = nil }
            }
        }
        .alert("Enter room code", isPresented: $showCodeEntry) {
            TextField("Room code", text: $codeText)
                // A Base58 code is not a word: ASCII layout, no capitalization,
                // correction or predictions.
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) { codeError = nil; codeText = "" }
            Button("Play") { submitCode(codeText) }
                .disabled(codeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            if let codeError {
                Text(codeError)
            } else {
                Text("The code is on your TV.")
            }
        }
        .fullScreenCover(item: $scanRequest, onDismiss: {
            // Deferred, like the info sheet's actions: presenting the alert while the
            // cover is still dismissing would be dropped by UIKit.
            if let action = pendingSheetAction {
                pendingSheetAction = nil
                requireName(action)
            }
        }) { request in
            // The scanner validates payloads itself (games passed in), so .code only
            // arrives for a value that resolves.
            QRScannerScreen(games: request.games) { result in
                scanRequest = nil
                switch result {
                case .code(let raw):
                    // The launcher's own privacy/imprint URL isn't a room — route it
                    // to the doc viewer (host-validated: the payload is untrusted)
                    // instead of failing it, same as the Universal Link path.
                    if let legal = PB.scannedLegalUrl(raw) {
                        successTick += 1
                        onOpenLegalDoc(legal)
                        return
                    }
                    resolveAndJoin(raw)
                case .enterCode:
                    pendingSheetAction = .enterCode
                case .failure(let message):
                    errorTick += 1
                    messages.showToast(String(localized: "Scanner unavailable: \(message)"), long: true)
                case .cancelled:
                    break
                }
            }
        }
        .appSheet(item: $profileRequest, onDismiss: { afterName = nil }) { request in
            ProfileSheet(
                initial: request.profile,
                title: String(localized: request.gated ? "Enter your name" : "Name"),
                cta: String(localized: request.gated ? "Save & continue" : "Save"),
                onSave: { p in
                    ProfileStore.save(p)
                    profile = p
                    // Clear the pending action BEFORE dismissal so onDismiss
                    // doesn't cancel the just-run action.
                    let pending = afterName
                    afterName = nil
                    profileRequest = nil
                    if let pending {
                        perform(pending)
                    }
                }
            )
        }
        .appSheet(item: $infoGame, onDismiss: {
            // Fire the funnel only after the sheet is fully gone — presenting the
            // scanner/alert mid-dismiss would be dropped by UIKit.
            if let action = pendingSheetAction {
                pendingSheetAction = nil
                requireName(action)
            }
        }) { game in
            GameInfoSheet(
                game: game,
                onScan: { pendingSheetAction = .scan; infoGame = nil },
                onEnterCode: { pendingSheetAction = .enterCode; infoGame = nil }
            )
        }
    }

    // MARK: Derived

    private var nearbyState: NearbyStatus {
        if !lanAsked { return .ask }
        if nearby.permissionDenied { return .denied }
        if !lan.hasLan { return .noWifi }
        return nearbySearchSettled ? .none : .searching
    }

    private var profileDisplayName: String {
        let trimmed = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "Set name") : trimmed
    }

    private func chipButton() -> some View {
        Button {
            // A second tap can land before the sheet covers the chip; a fresh request
            // id would make SwiftUI dismiss and re-present the sheet.
            guard profileRequest == nil else { return }
            profileRequest = ProfileSheetRequest(gated: false, profile: profile)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "person.crop.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                Text(profileDisplayName)
                    .font(.pbLabelLarge)
                    .lineLimit(1)
            }
            // .primary is scheme-adaptive, so the glass legibility flip works over posters.
            .foregroundStyle(Color.primary)
        }
    }

    private func aboutButton() -> some View {
        Button {
            onOpenAbout()
        } label: {
            // .primary rides the glass legibility adaptation; the default accent
            // tint would pin the color and ignore the poster art beneath the bar.
            Image(systemName: "info.circle")
                .foregroundStyle(Color.primary)
        }
        .accessibilityLabel("About")
    }

    // MARK: Join funnel

    @MainActor
    private func launchJoin(_ target: JoinOutcome) {
        guard case .success(let game, let roomCode, let joinUrl) = target else { return }
        successTick += 1
        RecentRoomStore.remember(game: game, joinUrl: joinUrl, roomCode: roomCode)
        onJoin(joinUrl, game.name, game.hosts)
    }

    @MainActor
    private func perform(_ action: AfterName) {
        switch action {
        case .scan:
            scanRequest = ScanRequest(games: games)
        case .enterCode:
            codeError = nil
            showCodeEntry = true
        case .join(let target):
            launchJoin(target)
        }
    }

    @MainActor
    private func requireName(_ action: AfterName) {
        if !profile.isSet {
            guard profileRequest == nil else { return }  // same double-tap guard as the chip
            afterName = action
            profileRequest = ProfileSheetRequest(gated: true, profile: profile)
        } else {
            perform(action)
        }
    }

    /// Scan, Universal Link, rejoin and nearby taps all land here. `resolveJoin` only
    /// touches the network for an origin-less input (a bare code or a paperballoon.games/<code>
    /// link) — a URL that names its own controller resolves offline, so a rejoin tap stays
    /// instant.
    @MainActor
    private func resolveAndJoin(_ raw: String) {
        joining = true
        Task { @MainActor in
            let outcome = await resolveJoin(raw, games: games)
            joining = false
            switch outcome {
            case .success:
                requireName(.join(outcome))
            case .failure(let message):
                errorTick += 1
                messages.showToast(message)
            }
        }
    }

    @MainActor
    private func submitCode(_ text: String) {
        codeError = nil
        joining = true
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        Task { @MainActor in
            let outcome = await resolveJoin(trimmed, games: games)
            joining = false
            switch outcome {
            case .success:
                codeText = ""
                launchJoin(outcome)
            case .failure(let message):
                // Alerts auto-dismiss on any action; re-present with the error
                // as the message so the player can correct the code.
                errorTick += 1
                codeError = message
                showCodeEntry = true
            }
        }
    }

    // MARK: Rejoin polling

    @MainActor
    private func runRejoinPoll() async {
        // Re-read the saved room EVERY iteration — never capture it once. A game that
        // ended with room_not_found clears the store from under this still-running poll;
        // the next tick must honor that and drop the card, not re-show the dead room off
        // a stale captured value + a relay record that hasn't 404'd yet.
        while !Task.isCancelled {
            // Nothing to verify: no saved room (never joined, aged out, cleared on a
            // room_not_found end), or a scanned URL that surfaced no code to probe with.
            guard let recent = RecentRoomStore.current(), !recent.roomCode.isEmpty else {
                withAnimation(.spring(duration: 0.45)) { rejoin = nil }
                return
            }
            // Every relay that could hold it, like the join path: only one of them
            // minted this room (see probeRoom).
            let results = await probeRoom(recent.roomCode, game: recent.game)
            if Task.isCancelled { return }
            let founds = results.filter(\.isFound)
            if founds.isEmpty {
                // Unconfirmed is unconfirmed: a relay that says the room is gone and one
                // we couldn't reach at all both mean no card. Only an ANSWER settles it,
                // though — a 404 from every relay that could hold the room ends it for
                // good, while an unreachable one just means we can't vouch for the offer
                // right now, so the room stays remembered and the next tick asks again.
                withAnimation(.spring(duration: 0.45)) { rejoin = nil }
                if !results.contains(.error) {
                    RecentRoomStore.clear()
                    return
                }
            } else {
                // Offered even when the room reads FULL. One of those slots is very
                // likely this player's own, held for them by the relay, which takes a
                // stored clientId back into it — the game only treats full as fatal for a
                // FRESH joiner. Hiding the card here locks someone out of the room they
                // were just in; a rejoin that genuinely bounces costs one page load and
                // lands on the `game_full` banner.
                //
                // The probe also carries the §6 template, so the room names its box here
                // even when nothing on the LAN is advertising it — re-read the slot to
                // pick that up.
                RecentRoomStore.putPlatform(fromTemplate: founds.lazy.compactMap(\.url).first)
                let room = RecentRoomStore.current() ?? recent
                withAnimation(.spring(duration: 0.45)) { rejoin = room }
            }
            do {
                try await Task.sleep(for: roomPollInterval)
            } catch {
                return
            }
        }
    }
}

// MARK: - Private types

/// Adds the "Controller" navigation subtitle where the OS supports it (iOS 26+).
/// A modifier rather than an inline `if #available` so the SDK-17 build compiles.
private struct HomeNavigationSubtitle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.navigationSubtitle(Text("Controller"))
        } else {
            content
        }
    }
}

private enum AfterName {
    case scan
    case enterCode
    case join(JoinOutcome)
}

private struct ProfileSheetRequest: Identifiable {
    let id = UUID()
    let gated: Bool
    let profile: Profile
}

private struct ScanRequest: Identifiable {
    let id = UUID()
    let games: [Game]
}

// MARK: - GameEndBanner

/// The game-end notice shown in the rejoin slot: a high-contrast strip that
/// auto-dismisses (timer lives in MessageCenter) and clears early on a tap or a
/// horizontal swipe.
private struct GameEndBanner: View {
    let message: String
    let onDismiss: () -> Void

    @Environment(\.pbPalette) private var palette
    @State private var dragX: CGFloat = 0

    var body: some View {
        Text(message)
            .font(.pbBodyMedium)
            .foregroundStyle(palette.inverseOnSurface)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 12).fill(palette.inverseSurface))
            .contentShape(Rectangle())
            .offset(x: dragX)
            .gesture(
                DragGesture()
                    .onChanged { dragX = $0.translation.width }
                    .onEnded { value in
                        if abs(value.translation.width) > 96 {
                            withAnimation(.easeOut(duration: 0.2)) {
                                dragX = value.translation.width > 0 ? 600 : -600
                            }
                            onDismiss()
                        } else {
                            withAnimation(.spring) { dragX = 0 }
                        }
                    }
            )
            .onTapGesture { onDismiss() }
    }
}

// MARK: - RoomCard

/// A room the player can enter right now — the one they just left, or one a display is
/// advertising. The two are the same object to a player, so they are one card; only where
/// the pieces come from differs, which is what `RejoinCard` and `NearbyCard` supply.
///
/// Glass on iOS 26 like the toolbar pills, a frosted fill before: rooms share the header's
/// material, apart from the solid game cards below. The game's colour lives on the icon
/// and nowhere else: routing it through the card's edge or fill made every HexStacker
/// card near-CTA red (its accent is #FF6B6B beside the sunset), which both read as an
/// alert and spent the one colour that's supposed to mean "this is how you play".
private struct RoomCard: View {
    let game: Game
    let title: String
    let roomCode: String
    /// The display's own label ("Wohnzimmer"). Blank when nothing on the LAN names the room.
    let label: String
    /// `pbp` — which box the room is on (§6). Nil when the URL declared nothing.
    let platform: String?
    let onTap: () -> Void

    @Environment(\.pbPalette) private var palette

    /// "Wohnzimmer · Apple TV" — which box, on its own line. Either half may be missing.
    private var locator: String {
        [label.isEmpty ? nil : label, deviceName(platform)].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                GameIcon(game: game, tint: palette.onSurface)
                VStack(alignment: .leading, spacing: 2) {
                    cardTitle(title, roomCode,
                              codeColor: palette.onSurface.opacity(0.55))
                        .font(.pbTitleMedium)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if !locator.isEmpty {
                        Text(locator)
                            .font(.pbBodyMedium)
                            .opacity(0.72)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .opacity(0.65)
            }
            .foregroundStyle(palette.onSurface)
            .padding(14)
            .frame(maxWidth: .infinity)
            .modifier(ChromeGlass(shape: RoundedRectangle(cornerRadius: 20, style: .continuous),
                                  fallback: palette.frosted))
        }
        .modifier(RoomCardPress())
    }
}

/// Interactive glass gives its own press feedback on iOS 26; the card's spring scale is
/// the cue before that. A modifier rather than an inline `if #available` so the SDK-17
/// build compiles.
private struct RoomCardPress: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.buttonStyle(.plain)
        } else {
            content.buttonStyle(PressableCardButtonStyle())
        }
    }
}

/// The room just left: its title comes from the controller page itself once captured, so
/// it beats the manifest's curated name.
///
/// `advert` is the same room as the LAN is currently advertising it, when it still is
/// (`HomeRooms.rejoinAdvert`) — the only source of the room's own NAME, and the freshest
/// source of its platform. Never the only source of that, though: an advertisement is
/// transient — a browser room is advertised only by the phones in it, so it stops naming
/// its box moments after this one leaves — so the platform lives on the room itself.
private struct RejoinCard: View {
    let room: RecentRoom
    var advert: NearbyRoom? = nil
    let onTap: () -> Void

    var body: some View {
        RoomCard(game: room.game,
                 title: room.title ?? room.game.name,
                 roomCode: room.roomCode,
                 label: advert?.label ?? "",
                 platform: advert?.platform ?? room.platform,
                 onTap: onTap)
    }
}

/// A room a display on this network is advertising (contract §8).
private struct NearbyCard: View {
    let room: NearbyRoom
    let onTap: () -> Void

    var body: some View {
        RoomCard(game: room.game,
                 title: room.game.name,
                 roomCode: room.roomCode,
                 label: room.label,
                 platform: room.platform,
                 onTap: onTap)
    }
}

/// "HexStacker A3KX9p" — the room code sits with the thing it belongs to, demoted in
/// color so the name still leads. One concatenated Text, so a long name truncates the
/// pair as a unit.
private func cardTitle(_ name: String, _ roomCode: String, codeColor: Color) -> Text {
    let title = Text(name)
    guard !roomCode.isEmpty else { return title }
    return title + Text("  \(roomCode)").foregroundColor(codeColor)
}

// MARK: - NearbyStatusCard

/// Where discovery currently stands, when it has no room to show for it.
enum NearbyStatus {
    /// Local Network never asked for.
    case ask
    case searching
    case none
    /// Asked, but no Wi-Fi/Ethernet is up — nothing local to search, so the slot
    /// says how to fix that instead of claiming a search happened.
    case noWifi
    /// Local Network was denied, which is unrecoverable in-app.
    case denied
}

/// What the TV slot shows when there are no rooms to show.
///
/// `ask` and `denied` are one design: a muted info line in the OS's own
/// permission-education formula — "To [what you want], allow [the toggle by its system
/// name]" — goal first, then the concrete thing to flip, over a button that carries only
/// the verb — ask the system, or open Settings once that's the one place that can still
/// answer. The info line reuses the muted-status row, so every state of the slot is one
/// icon-plus-line; the button stays bare-verb tonal like the info sheet's "Enter code
/// manually", at the same size. Tonal, not the sunset: this is one-time setup that
/// vanishes for good once granted, and it must not outshout the scan CTA you use every
/// session.
///
/// Once granted, searching, not-found and the off-Wi-Fi hint collapse to a muted line — an
/// idle home screen shouldn't carry a box announcing that a TV simply isn't switched on.
private struct NearbyStatusCard: View {
    let state: NearbyStatus
    let onAsk: () -> Void
    let onOpenSettings: () -> Void

    @Environment(\.pbPalette) private var palette

    var body: some View {
        switch state {
        case .ask:
            askBlock(Text("Allow"), action: onAsk)
        case .denied:
            askBlock(Text("Open Settings"), action: onOpenSettings)
        case .searching:
            statusLine(Text("Searching for rooms…"), showsProgress: true)
        case .noWifi:
            statusLine(Text("Connect to Wi-Fi to find rooms nearby"), icon: "wifi.slash")
        case .none:
            statusLine(Text("No rooms found"))
        }
    }

    private func askBlock(_ verb: Text, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Default antenna glyph on purpose: Android's info line quotes the toggle's
            // system icon, but Apple's Settings gives "Local Network" no icon to quote.
            statusLine(Text("To connect directly to the TV, allow **Local Network**."))
            askButton(verb, action: action)
        }
    }

    private func askButton(_ text: Text, action: @escaping () -> Void) -> some View {
        SecondaryButton(action: action) { text }
    }

    /// A 48pt minimum height keeps the muted states interchangeable without the cards
    /// below moving.
    private func statusLine(
        _ text: Text,
        icon: String = "antenna.radiowaves.left.and.right",
        showsProgress: Bool = false
    ) -> some View {
        // The button's metrics (glyph and title size) so the slot doesn't change scale
        // as it moves between offering and reporting — only the muted color says "status".
        HStack(spacing: 10) {
            if showsProgress {
                ProgressView().controlSize(.regular)
            } else {
                Image(systemName: icon).font(.pbTitleMedium)
            }
            text.font(.pbTitleMedium)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - GameCard

/// The language's card: flat, the card fill with one hairline, the poster whole and
/// untouched on top, and the name under it with its tag beside it, the player count at
/// the right and where it runs below. The whole card is the tap.
private struct GameCard: View {
    let game: Game
    let onTap: () -> Void

    @Environment(\.pbPalette) private var palette

    /// Where it runs: each live TV app, then the browser host. A game with neither (not
    /// out yet) has no row.
    private var meta: [(icon: String, label: String)] {
        var items: [(String, String)] = []
        for (id, name) in tvPlatforms where game.tvApps[id] == "live" {
            items.append(("tv", String(localized: name)))
        }
        if let host = game.displayHost { items.append(("globe", host)) }
        return items
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                GameArt(game: game)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Text(game.name)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(palette.onSurface)
                                .lineLimit(1)
                            StatusTag(game: game)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // "1–8" with the person glyph standing in for the word "players"
                        // (Game.playersRange).
                        if let range = game.playersRange {
                            HStack(spacing: 6) {
                                Image(systemName: "person.2")
                                    .font(.system(size: 14, weight: .medium))
                                Text(range)
                                    .font(.subheadline.weight(.medium))
                            }
                            .foregroundStyle(palette.onSurfaceVariant)
                        }
                    }
                    let places = meta
                    if !places.isEmpty {
                        HStack(spacing: 14) {
                            ForEach(places.indices, id: \.self) { i in
                                HStack(spacing: 5) {
                                    Image(systemName: places[i].icon)
                                        .font(.system(size: 12, weight: .medium))
                                    Text(places[i].label)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .foregroundStyle(palette.onSurfaceVariant)
                    }
                }
                .padding(EdgeInsets(top: 12, leading: 14, bottom: 14, trailing: 14))
            }
            .background(palette.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(palette.outlineVariant, lineWidth: 1)
            )
        }
        .buttonStyle(PressableCardButtonStyle())
    }
}

// MARK: - SkyBackdrop

/// The home sky behind the catalog, scrolling with it. One dusk: lilac at the zenith,
/// peach at the horizon, fading into the paper by the first card — with flat white
/// clouds by day; by night the clouds go, the stars come out and the ground is the night violet.
/// The fleet flies beside the large title: the sunset balloon leads, sea, gold and dusk
/// follow. The background of the scroll content, so it travels with the title; placed in
/// points from the top of the content (just under the large title; negative is above
/// it) and from the screen's edges. Android's SkyBackdrop (MainScreen.kt) draws the
/// same sky around its own title.
private struct SkyBackdrop: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.pbPalette) private var palette

    // How far the sky reaches above the content: past the top of the screen, with room to
    // spare for a pull-down bounce.
    private static let above: CGFloat = 1000
    // The sky's stops, from the content top: where the screen's top sits on the phone
    // the language was drawn for, the horizon (peach), where the night's flat sky starts
    // to fade, and where either has become the paper.
    private static let screenTop: CGFloat = -193
    private static let horizon: CGFloat = 27
    private static let nightFlat: CGFloat = 107
    private static let paper: CGFloat = 327
    // x as a fraction of the width, y, radius.
    private static let stars: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [
        (0.08, -153, 1.2), (0.31, -103, 1), (0.51, -163, 1.3), (0.77, -123, 1), (0.92, -43, 1.2),
        (0.18, -3, 1), (0.64, 17, 1.1), (0.85, 107, 1), (0.10, 137, 1.2), (0.46, 197, 1),
        (0.15, -173, 0.8), (0.41, -133, 1.2), (0.62, -73, 0.9), (0.87, -163, 1), (0.05, -83, 1.3),
        (0.28, -43, 0.8), (0.74, -33, 1.1), (0.95, 17, 0.9), (0.38, 37, 1), (0.21, 67, 1.2),
        (0.56, 87, 0.8), (0.77, 57, 1.3), (0.08, 177, 0.9), (0.33, 147, 1.1), (0.67, 157, 0.8),
        (0.90, 187, 1.2), (0.49, 217, 0.9), (0.95, -93, 0.8),
    ]
    // Clouds: left (from the screen's right edge when `fromRight`), top, width. One
    // overflows the left edge, one drifts behind the fleet at the right — never behind
    // the toolbar pills or over the status line below.
    private static let clouds: [(x: CGFloat, y: CGFloat, width: CGFloat, fromRight: Bool)] = [
        (-12, -140, 118, false), (-10, -100, 150, true), (118, -162, 54, false),
    ]
    // The fleet in colour order (sunset, sea, gold, dusk): width, end margin, top. The
    // sunset is the biggest; the rest fly smaller and further off.
    private static let fleet: [(width: CGFloat, end: CGFloat, top: CGFloat)] = [
        (40, 48, -75), (24, 104, -43), (15, 20, -81), (17, 5, -45),
    ]
    private static let balloonAspect: CGFloat = 58 / 82.43  // SkyBalloon's viewBox

    var body: some View {
        let dark = scheme == .dark
        let fleetColors = [
            dark ? PBPalette.fleetSunsetNight : PBPalette.fleetSunset,
            PBPalette.fleetSea,
            PBPalette.fleetGold,
            dark ? PBPalette.fleetDuskNight : PBPalette.fleetDusk,
        ]
        let height = Self.above + Self.paper
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    stops: dark ? [
                        .init(color: PBPalette.skyDark, location: (Self.above + Self.nightFlat) / height),
                        .init(color: palette.background, location: 1),
                    ] : [
                        .init(color: PBPalette.skyLight[0], location: (Self.above + Self.screenTop) / height),
                        .init(color: PBPalette.skyLight[1], location: (Self.above + Self.horizon) / height),
                        .init(color: palette.background, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: width, height: height)
                if dark {
                    ForEach(Self.stars.indices, id: \.self) { i in
                        let star = Self.stars[i]
                        Circle()
                            .fill(palette.onSurface.opacity(0.75))
                            .frame(width: star.r * 2, height: star.r * 2)
                            .position(x: star.x * width, y: Self.above + star.y)
                    }
                } else {
                    ForEach(Self.clouds.indices, id: \.self) { i in
                        let cloud = Self.clouds[i]
                        Puff()
                            .fill(.white)
                            .frame(width: cloud.width, height: cloud.width * 0.45)
                            .offset(x: cloud.fromRight ? width + cloud.x - cloud.width : cloud.x,
                                    y: Self.above + cloud.y)
                    }
                }
                ForEach(Self.fleet.indices, id: \.self) { i in
                    let balloon = Self.fleet[i]
                    let balloonHeight = balloon.width / Self.balloonAspect
                    // The silhouette masks the balloon's gradient.
                    LinearGradient(colors: fleetColors[i], startPoint: .top, endPoint: .bottom)
                        .mask(Image("SkyBalloon").resizable())
                        .frame(width: balloon.width, height: balloonHeight)
                        .offset(x: width - balloon.end - balloon.width, y: Self.above + balloon.top)
                }
            }
            .offset(y: -Self.above)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A flat cloud: a rounded bar with three circles rising from it, on a 200×90 grid.
private struct Puff: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 200
        var path = Path()
        path.addRoundedRect(in: CGRect(x: rect.minX + 16 * s, y: rect.minY + 52 * s, width: 168 * s, height: 34 * s),
                            cornerSize: CGSize(width: 17 * s, height: 17 * s))
        for (cx, cy, r) in [(62.0, 54.0, 30.0), (106.0, 44.0, 38.0), (150.0, 58.0, 24.0)] {
            path.addEllipse(in: CGRect(x: rect.minX + (cx - r) * s, y: rect.minY + (cy - r) * s,
                                       width: 2 * r * s, height: 2 * r * s))
        }
        return path
    }
}

// MARK: - JoinDock (floating over the poster list)

/// The dock at the thumb: scan, and the keyboard for a typed code. Glass where the OS
/// has it.
private struct JoinDock: View {
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

/// The dock's bar at the bottom edge. iOS 26 has a bar with the soft scroll edge, a
/// progressive blur the list dissolves into; before that the list dissolves into a fade
/// of the paper instead. A modifier rather than an inline `if #available` so the SDK-17
/// build compiles.
private struct DockBar<Bar: View>: ViewModifier {
    @ViewBuilder let bar: () -> Bar

    @Environment(\.pbPalette) private var palette

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .scrollEdgeEffectStyle(.soft, for: .bottom)
                .safeAreaBar(edge: .bottom) { bar() }
        } else {
            content
                .safeAreaInset(edge: .bottom) {
                    bar()
                        .padding(.top, 40)
                        .background(
                            LinearGradient(
                                stops: [
                                    .init(color: palette.background.opacity(0), location: 0),
                                    .init(color: palette.background, location: 0.4),
                                    .init(color: palette.background, location: 1),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .ignoresSafeArea(edges: .bottom)
                        )
                }
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

// MARK: - Previews

/// The home screen's room-card states in one strip, fed by CardSamples so the ones that
/// otherwise need a live room — an Android TV display, a game with no manifest icon, a
/// name long enough to truncate — are reachable while editing. The cards are theme
/// chrome, so the light/dark pair is checking that they adapt rather than sitting as a
/// slab. Mirrored by Android `MainScreen.kt`; a card change wants both.
private struct PreviewStrip<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            // Home's own card spacing and padding, so the previews show the gaps the
            // real screen has.
            VStack(spacing: 12) { content }
                .padding(16)
        }
        .background(Color(.systemBackground))
        .pbThemed()
    }
}

#Preview("Nearby — light") {
    PreviewStrip {
        NearbyStatusCard(state: .ask, onAsk: {}, onOpenSettings: {})
        NearbyStatusCard(state: .searching, onAsk: {}, onOpenSettings: {})
        NearbyStatusCard(state: .none, onAsk: {}, onOpenSettings: {})
        NearbyStatusCard(state: .noWifi, onAsk: {}, onOpenSettings: {})
        NearbyStatusCard(state: .denied, onAsk: {}, onOpenSettings: {})
        NearbyCard(room: CardSamples.nearbyFull) {}
        NearbyCard(room: CardSamples.nearbyDeviceOnly) {}
        NearbyCard(room: CardSamples.nearbyLabelOnly) {}
        NearbyCard(room: CardSamples.nearbyBare) {}
        NearbyCard(room: CardSamples.nearbyAndroidTv) {}
        NearbyCard(room: CardSamples.nearbyIconless) {}
        NearbyCard(room: CardSamples.nearbyLongName) {}
    }
}

#Preview("Nearby — dark") {
    PreviewStrip {
        NearbyStatusCard(state: .ask, onAsk: {}, onOpenSettings: {})
        NearbyStatusCard(state: .searching, onAsk: {}, onOpenSettings: {})
        NearbyStatusCard(state: .none, onAsk: {}, onOpenSettings: {})
        NearbyStatusCard(state: .noWifi, onAsk: {}, onOpenSettings: {})
        NearbyStatusCard(state: .denied, onAsk: {}, onOpenSettings: {})
        NearbyCard(room: CardSamples.nearbyFull) {}
        NearbyCard(room: CardSamples.nearbyAndroidTv) {}
        NearbyCard(room: CardSamples.nearbyIconless) {}
        NearbyCard(room: CardSamples.nearbyLongName) {}
    }
    .preferredColorScheme(.dark)
}

#Preview("Rejoin — light") {
    PreviewStrip {
        RejoinCard(room: CardSamples.rejoinPlain) {}
        RejoinCard(room: CardSamples.rejoinIconless) {}
        RejoinCard(room: CardSamples.rejoinPageTitle) {}
        RejoinCard(room: CardSamples.rejoinNoCode) {}
        RejoinCard(room: CardSamples.rejoinWithDevice) {}
        // The room's display is still advertising: its name joins the locator, and its
        // relay-declared platform stands in for a remembered URL that named no box.
        RejoinCard(room: CardSamples.rejoinPlain, advert: CardSamples.nearbyFull) {}
        RejoinCard(room: CardSamples.rejoinWeb) {}
    }
}

#Preview("Rejoin — dark") {
    PreviewStrip {
        RejoinCard(room: CardSamples.rejoinPlain) {}
        RejoinCard(room: CardSamples.rejoinIconless) {}
    }
    .preferredColorScheme(.dark)
}
