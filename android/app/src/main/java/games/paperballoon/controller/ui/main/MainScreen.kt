package games.paperballoon.controller.ui.main

import android.Manifest
import android.content.Intent
import android.content.res.Configuration.UI_MODE_NIGHT_YES
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.widget.Toast
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.layout.windowInsetsTopHeight
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.OutlinedIconButton
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshots.SnapshotStateMap
import androidx.compose.ui.Alignment
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.BlurEffect
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.TileMode
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.layer.GraphicsLayer
import androidx.compose.ui.graphics.layer.CompositingStrategy as LayerCompositingStrategy
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.graphics.rememberGraphicsLayer
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalResources
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.annotation.DrawableRes
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import games.paperballoon.controller.data.Game
import games.paperballoon.controller.data.ManifestStore
import games.paperballoon.controller.data.JoinOutcome
import games.paperballoon.controller.data.AdvertLinger
import games.paperballoon.controller.data.NearbyAdvert
import games.paperballoon.controller.data.NearbyRoom
import games.paperballoon.controller.data.distinctAdverts
import games.paperballoon.controller.data.nearbyAdverts
import games.paperballoon.controller.data.homeRooms
import games.paperballoon.controller.data.lanAvailable
import games.paperballoon.controller.data.resolveNearby
import games.paperballoon.controller.data.clearLocalNetworkAsked
import games.paperballoon.controller.data.localNetworkPermanentlyDenied
import games.paperballoon.controller.data.localNetworkPermissionGranted
import games.paperballoon.controller.data.markLocalNetworkAsked
import games.paperballoon.controller.data.nearbyOptedIn
import games.paperballoon.controller.data.setNearbyOptedIn
import games.paperballoon.controller.data.Profile
import games.paperballoon.controller.data.ProfileStore
import games.paperballoon.controller.data.RecentRoom
import games.paperballoon.controller.data.RecentRoomStore
import games.paperballoon.controller.data.ROOM_POLL_MS
import games.paperballoon.controller.data.RoomLookup
import games.paperballoon.controller.data.probeRoom
import games.paperballoon.controller.data.resolveJoin
import androidx.compose.ui.tooling.preview.Preview
import games.paperballoon.controller.theme.PaperBalloonTheme
import games.paperballoon.controller.theme.FleetDusk
import games.paperballoon.controller.theme.FleetDuskNight
import games.paperballoon.controller.theme.FleetGold
import games.paperballoon.controller.theme.FleetSea
import games.paperballoon.controller.theme.FleetSunset
import games.paperballoon.controller.theme.FleetSunsetNight
import games.paperballoon.controller.theme.SkyLight
import games.paperballoon.controller.theme.SkyNight
import games.paperballoon.controller.theme.card
import games.paperballoon.controller.theme.frosted
import games.paperballoon.controller.theme.ghost
import games.paperballoon.controller.theme.ghostLine
import games.paperballoon.controller.theme.isDark
import games.paperballoon.controller.ui.preview.CardSamples
import games.paperballoon.controller.ui.legal.LegalLinks
import games.paperballoon.controller.R
import games.paperballoon.controller.ui.components.ART_LUMINANCE_ROWS
import games.paperballoon.controller.ui.components.Art
import games.paperballoon.controller.ui.components.BarIcons
import games.paperballoon.controller.ui.components.GameArt
import games.paperballoon.controller.ui.components.GameIcon
import games.paperballoon.controller.ui.components.rememberArt
import games.paperballoon.controller.ui.components.deviceName
import games.paperballoon.controller.ui.components.findActivity
import games.paperballoon.controller.ui.components.ScanButton
import games.paperballoon.controller.ui.components.SunsetButton
import games.paperballoon.controller.ui.components.JoiningCover
import games.paperballoon.controller.ui.components.PlayerChip
import games.paperballoon.controller.ui.components.StatusTag
import games.paperballoon.controller.ui.components.stableScreenInsets
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
fun MainScreen(
  modifier: Modifier = Modifier,
  deepLink: String? = null,
  onDeepLinkConsumed: () -> Unit = {},
  onJoin: (joinUrl: String, title: String, allowedHosts: List<String>) -> Unit = { _, _, _ -> },
  onOpenLegalDoc: (url: String) -> Unit = {},
  onOpenAbout: () -> Unit = {},
  // Set when a game reports it ended and the host popped back here — shown as a banner
  // in the rejoin slot. Cleared on dismiss (auto after a few seconds, or tap/swipe).
  gameEndBanner: String? = null,
  onDismissGameEndBanner: () -> Unit = {},
  onBarIcons: (BarIcons) -> Unit = {},
) {
  val context = LocalContext.current
  // Config-aware resources for string lookups in callbacks (context.getString on
  // LocalContext.current is flagged by lint as not tracking config changes).
  val resources = LocalResources.current
  val scope = rememberCoroutineScope()
  val haptics = LocalHapticFeedback.current
  val lifecycleOwner = LocalLifecycleOwner.current
  // Seeded synchronously (cached fetch, else bundled); the once-per-launch
  // refresh below updates it live when the served manifest differs.
  val games by ManifestStore.games(context).collectAsState()
  var profile by remember { mutableStateOf(ProfileStore.load(context)) }
  var showProfile by remember { mutableStateOf(false) }
  var afterName by remember { mutableStateOf<AfterName?>(null) }
  var showScanner by remember { mutableStateOf(false) }
  var showCodeEntry by remember { mutableStateOf(false) }
  var codeLoading by remember { mutableStateOf(false) }
  var codeError by remember { mutableStateOf<String?>(null) }
  // A join being resolved outside the code dialog (which reports progress on its own
  // submit button): the directory probe a scan or App Link now takes can cost a round trip.
  var joining by remember { mutableStateOf(false) }
  var rejoin by remember { mutableStateOf<RecentRoom?>(null) }
  var infoGame by remember { mutableStateOf<Game?>(null) }
  // Rooms advertised on the LAN by native display apps (contract §8). Resolved against
  // `games` on every change, so a manifest refresh re-admits (or drops) an advert
  // without restarting discovery.
  var adverts by remember { mutableStateOf<List<NearbyAdvert>>(emptyList()) }
  // Opt-in gates discovery: ungranted → the nearby slot's "Allow" button, granted →
  // discovery runs on every later launch and the rooms are simply there. On API 37+
  // the permission is the opt-in memory; below enforcement a stored flag stands in
  // (see nearbyOptedIn). No prompt at first launch; the user asks for it once.
  var canDiscover by remember { mutableStateOf(nearbyOptedIn(context)) }
  // …unless the ask has been refused into a lock, at which point the button would be a
  // control that does nothing (see localNetworkPermanentlyDenied).
  var discoveryLocked by remember {
    mutableStateOf(localNetworkPermanentlyDenied(context, context.findActivity()))
  }
  // Re-read both from the system, and drop the asked-once record while the permission is
  // held — see clearLocalNetworkAsked for why a grant has to forget it.
  fun refreshDiscovery() {
    canDiscover = nearbyOptedIn(context)
    if (localNetworkPermissionGranted(context)) clearLocalNetworkAsked(context)
    discoveryLocked = localNetworkPermanentlyDenied(context, context.findActivity())
  }
  val localNetworkPermission = rememberLauncherForActivityResult(
    ActivityResultContracts.RequestPermission(),
  ) { refreshDiscovery() }
  // Coming back from Settings after a grant there — no callback fires, so re-probe. This
  // is also what makes a hand-edited permission take effect without a relaunch. (A revoke
  // arrives as a process kill instead, so the initializers above cover that direction.)
  LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { refreshDiscovery() }
  // An advertised code becomes a card only once the relay has resolved it — that call is
  // what supplies the join URL, `pbp` and the occupancy check. Re-checked on the same
  // cadence as the rejoin card: both promise "you can enter this", so both have to notice
  // when the room dies or fills. Lifecycle-gated — no polling while backgrounded.
  val resolved = remember { mutableStateMapOf<String, NearbyRoom>() }
  // A record that stops appearing doesn't end a room — only the relay does, and a held
  // room keeps being probed until it answers (see AdvertLinger).
  val linger = remember { AdvertLinger() }
  LaunchedEffect(adverts, games) {
    lifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
      while (true) {
        // One probe per ROOM, not per record: a room announced by its display and by
        // every phone in it is still one code.
        val distinct = linger.hold(distinctAdverts(adverts))
        resolved.keys.retainAll(distinct.map { it.code }.toSet())
        coroutineScope {
          distinct.map { advert ->
            async {
              val room = resolveNearby(advert, games)
              if (room == null) resolved.remove(advert.code) else resolved[advert.code] = room
            }
          }.awaitAll()
        }
        delay(ROOM_POLL_MS)
      }
    }
  }
  // The rejoin room's own advertisement folds INTO the rejoin card, name and all, rather
  // than standing up a second card for the room the player is already being offered.
  val home = remember(resolved.toMap(), rejoin) { homeRooms(resolved.values.toList(), rejoin) }
  val nearby = home.nearby
  // Whether a network mDNS could traverse — Wi-Fi or Ethernet — is up at all. Only picks
  // the status line's wording — discovery keeps running regardless (see lanAvailable on
  // the hotspot case).
  var hasLan by remember { mutableStateOf(true) }
  LaunchedEffect(Unit) {
    lifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
      lanAvailable(context).collect { hasLan = it }
    }
  }
  // mDNS discovery never "completes" — it just keeps listening — so a spinner would spin
  // forever with the TV off. Settle to a plain "not found" after a grace period. Keyed on
  // hasLan too: Wi-Fi coming back restarts the grace period, so the slot reads
  // "Searching…" again instead of a stale instant "No rooms found".
  var searchSettled by remember { mutableStateOf(false) }
  LaunchedEffect(canDiscover, hasLan) {
    searchSettled = false
    if (canDiscover) {
      delay(8_000)
      searchSettled = true
    }
  }

  // Every successful join funnels through here: remember the room for one-tap
  // rejoin and open the game host. Closes the scanner too, so leaving the game
  // lands back on home, not on a live camera.
  fun launchJoin(target: JoinOutcome.Success) {
    haptics.performHapticFeedback(HapticFeedbackType.Confirm)
    showScanner = false
    RecentRoomStore.remember(target.game, target.joinUrl, target.roomCode)
    onJoin(target.joinUrl, target.game.name, target.game.hosts)
  }

  // Every failure surface — a bad link, a dead room — pairs the toast with a
  // rejection buzz, mirroring iOS's error haptic.
  fun fail(messageRes: Int) {
    haptics.performHapticFeedback(HapticFeedbackType.Reject)
    Toast.makeText(context, resources.getString(messageRes), Toast.LENGTH_SHORT).show()
  }

  fun perform(action: AfterName) {
    when (action) {
      AfterName.Scan -> showScanner = true
      AfterName.EnterCode -> { codeError = null; showCodeEntry = true }
      is AfterName.Join -> launchJoin(action.target)
    }
  }

  // Gate any join behind a non-blank name: prompt first if missing, else act now.
  fun requireName(action: AfterName) {
    if (!profile.isSet) {
      afterName = action
      showProfile = true
    } else {
      perform(action)
    }
  }

  // Scan, App Link, rejoin and nearby taps all land here. [resolveJoin] only touches the
  // network for an origin-less input (a bare code or a paperballoon.games/<code> link) — a URL
  // that names its own controller resolves offline, so a rejoin tap stays instant.
  fun resolveAndJoin(raw: String) {
    scope.launch {
      joining = true
      val r = resolveJoin(raw, games)
      joining = false
      when (r) {
        is JoinOutcome.Success -> requireName(AfterName.Join(r))
        is JoinOutcome.Failure -> fail(r.messageRes)
      }
    }
  }

  // Pull the served manifest once per launch (ManifestStore guards re-entry, so
  // nav pop-backs recomposing this screen don't refetch).
  LaunchedEffect(Unit) { ManifestStore.refresh(context) }

  // Browse for nearby rooms only while home is STARTED and the permission is held —
  // cancelling the collection stops discovery and drops the multicast lock, so nothing
  // runs in the background or behind the game host.
  LaunchedEffect(canDiscover) {
    if (!canDiscover) {
      adverts = emptyList()
      return@LaunchedEffect
    }
    lifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
      try {
        nearbyAdverts(context).collect { adverts = it }
      } finally {
        adverts = emptyList()
      }
    }
  }

  // An incoming App Link: a legal-page link opens the in-app doc viewer; anything
  // else is a join and goes through the same name gate as a scan. The URL keeps its
  // locale segment (/en/privacy vs /privacy), so the viewer loads the right variant.
  LaunchedEffect(deepLink) {
    if (deepLink != null) {
      if (LegalLinks.isPrivacy(deepLink) || LegalLinks.isImprint(deepLink)) {
        onOpenLegalDoc(deepLink)
      } else {
        resolveAndJoin(deepLink)
      }
      onDeepLinkConsumed()
    }
  }

  // Offer one-tap rejoin while the last-joined room is still alive: keep probing the
  // relays that could hold it so the card clears itself when the room dies.
  // Lifecycle-gated — no polling while backgrounded.
  LaunchedEffect(Unit) {
    lifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
      // Re-read the saved room EVERY iteration — never capture it once. A game that
      // ended with room_not_found clears the store from under this still-running poll;
      // the next tick must honor that and drop the card, not re-show the dead room off
      // a stale captured value + a relay record that hasn't 404'd yet.
      while (true) {
        val recent = RecentRoomStore.current()
        // Nothing to verify: no saved room (never joined, aged out, cleared on a
        // room_not_found end), or a scanned URL that surfaced no code to probe with.
        if (recent == null || recent.roomCode.isBlank()) {
          rejoin = null
          return@repeatOnLifecycle
        }
        // Every relay that could hold it, like the join path: only one of them minted
        // this room (see probeRoom).
        val results = probeRoom(recent.roomCode, recent.game)
        val founds = results.filterIsInstance<RoomLookup.Found>()
        if (founds.isEmpty()) {
          // Unconfirmed is unconfirmed: a relay that says the room is gone and one we
          // couldn't reach at all both mean no card. Only an ANSWER settles it, though —
          // a 404 from every relay that could hold the room ends it for good, while an
          // unreachable one just means we can't vouch for the offer right now, so the
          // room stays remembered and the next tick asks again.
          rejoin = null
          if (results.none { it is RoomLookup.Error }) {
            RecentRoomStore.clear()
            return@repeatOnLifecycle
          }
        } else {
          // Offered even when the room reads FULL. One of those slots is very likely
          // this player's own, held for them by the relay, which takes a stored clientId
          // back into it — the game only treats full as fatal for a FRESH joiner. Hiding
          // the card here locks someone out of the room they were just in; a rejoin that
          // genuinely bounces costs one page load and lands on the `game_full` banner.
          //
          // The probe also carries the §6 template, so the room names its box here even
          // when nothing on the LAN is advertising it — re-read the slot to pick that up.
          RecentRoomStore.putPlatform(founds.firstOrNull { it.url != null }?.url)
          rejoin = RecentRoomStore.current() ?: recent
        }
        delay(ROOM_POLL_MS)
      }
    }
  }

  // The status bar is fully transparent and its icons follow what's under them. Posters
  // scroll under it, so each GameCard reports whether its art is light where the bar's
  // icon row crosses it (keyed by game; cleared while it's elsewhere) — with no poster
  // there the theme's background is under the bar. The scanner is a dark surface over
  // everything.
  val underBar = remember { mutableStateMapOf<String, Boolean>() }
  val themeLight = !isSystemInDarkTheme()
  val lightStatus by remember(themeLight) {
    derivedStateOf { underBar.values.firstOrNull() ?: themeLight }
  }
  val bars = BarIcons(lightStatus = lightStatus && !showScanner, lightNav = themeLight && !showScanner)
  SideEffect { onBarIcons(bars) }

  // Games scroll the full screen; the dock floats over the list at the bottom.
  // The trailing Spacer, sized off the dock's measured height, keeps the last
  // poster reachable. The scanner overlay sits in the same root Box but OUTSIDE
  // the inset padding — the camera runs edge to edge and pads its own controls.
  var dockHeightPx by remember { mutableStateOf(0) }
  Box(modifier.fillMaxSize()) {
    // Only the horizontal (cutout) inset pads the container. The status bar and nav
    // bar are applied INSIDE the scroll (top spacer + card bottom inset) so the
    // catalog scrolls edge to edge UNDER the transparent bars instead of being
    // clipped in a box below them.
    Box(
      Modifier
        .fillMaxSize()
        .windowInsetsPadding(stableScreenInsets.only(WindowInsetsSides.Horizontal)),
    ) {
      val scroll = rememberScrollState()
      SkyBackdrop(scrolled = { scroll.value })
      // The list is drawn through a layer so the dock's edge can draw it again, blurred.
      val listLayer = rememberGraphicsLayer()
      Column(
        Modifier
          .fillMaxSize()
          .drawWithContent {
            listLayer.record { this@drawWithContent.drawContent() }
            drawLayer(listLayer)
          }
          .verticalScroll(scroll),
      ) {
        // Clears the status bar so the header starts below it, but scrolls away with
        // the content — posters slide under the transparent bar, not into a hard cut.
        Spacer(Modifier.windowInsetsTopHeight(stableScreenInsets))
        HomeTopBar(profile = profile, onEditProfile = { showProfile = true }, onOpenAbout = onOpenAbout)
        // One rhythm for the whole stack: the banner, every room card and every poster
        // are cards in a single list, so they all sit 12dp apart. The two sections, rooms
        // you can enter and the catalog, each open under a heading with room above it.
        Column(
          Modifier
            .padding(horizontal = 16.dp)
            .padding(top = 20.dp),
          verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
          // The game-end notice sits at the top of the content, above the rejoin card
          // (which is only present when the room is still alive). A high-contrast strip
          // rather than a bottom snackbar — the player was returned here, so the notice
          // needs to land where their eye already is.
          GameEndBanner(message = gameEndBanner, onDismiss = onDismissGameEndBanner)
          // Always over something: a room card, or the status line saying why there's none.
          SectionTitle(stringResource(R.string.rooms_title))
          // A relay-confirmed room springs the rejoin card in; when the room dies it
          // springs back out. Retain the last target so the exit animation still has
          // content to render after `rejoin` clears (mirrors iOS's scale+fade).
          var lastRejoin by remember { mutableStateOf<RecentRoom?>(null) }
          LaunchedEffect(rejoin) { rejoin?.let { lastRejoin = it } }
          AnimatedVisibility(
            visible = rejoin != null,
            enter = fadeIn() + scaleIn(initialScale = 0.96f),
            exit = fadeOut() + scaleOut(targetScale = 0.96f),
          ) {
            lastRejoin?.let { room ->
              RejoinCard(room, home.rejoinAdvert, primary = true) { resolveAndJoin(room.joinUrl) }
            }
          }
          // "Searching…" / "No rooms found" are claims about having looked and come up
          // empty — false while a room card is already on screen, rejoin included. The
          // ask is an offer rather than a claim, so it stays regardless: hiding it behind
          // a rejoin card would make discovery invisible for the rest of the session. So
          // does the denied button, which is the same offer by another route.
          val nearbyState = when {
            discoveryLocked -> NearbyStatus.Denied
            !canDiscover -> NearbyStatus.Ask
            !hasLan -> NearbyStatus.NoWifi
            searchSettled -> NearbyStatus.None
            else -> NearbyStatus.Searching
          }
          val offering = nearbyState == NearbyStatus.Ask || nearbyState == NearbyStatus.Denied
          if (offering || (nearby.isEmpty() && rejoin == null)) {
            NearbyStatusCard(
              state = nearbyState,
              onAsk = {
                if (Build.VERSION.SDK_INT >= 37) {
                  markLocalNetworkAsked(context)
                  localNetworkPermission.launch(Manifest.permission.ACCESS_LOCAL_NETWORK)
                } else {
                  // No permission to ask for below enforcement — the tap is the grant.
                  setNearbyOptedIn(context)
                  refreshDiscovery()
                }
              },
              onOpenSettings = {
                context.startActivity(
                  Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.fromParts("package", context.packageName, null),
                  ),
                )
              },
            )
          }
          // Same retain-the-last-value trick as the rejoin card, so the exit
          // animation still has content to render after the list empties.
          var lastNearby by remember { mutableStateOf<List<NearbyRoom>>(emptyList()) }
          LaunchedEffect(nearby) { if (nearby.isNotEmpty()) lastNearby = nearby }
          AnimatedVisibility(
            visible = nearby.isNotEmpty(),
            enter = fadeIn() + scaleIn(initialScale = 0.96f),
            exit = fadeOut() + scaleOut(targetScale = 0.96f),
          ) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
              lastNearby.forEachIndexed { i, room ->
                NearbyCard(room, primary = rejoin == null && i == 0) { requireName(AfterName.Join(room.target)) }
              }
            }
          }
          GamesSection(games, underBar, Modifier.padding(top = 20.dp), onOpen = { infoGame = it })
          Spacer(Modifier.height(with(LocalDensity.current) { dockHeightPx.toDp() } + 28.dp))
        }
      }
      // The list dissolves into a blur under the dock, like iOS's soft scroll edge; the
      // list's trailing spacer keeps the last card reachable.
      val bottomInset = with(LocalDensity.current) { stableScreenInsets.getBottom(this).toDp() }
      DockEdge(
        list = listLayer,
        scrolled = { scroll.value },
        modifier = Modifier.align(Alignment.BottomCenter).height(bottomInset + 12.dp + 56.dp + DOCK_EDGE_ABOVE),
      )
      JoinDock(
        onScan = { requireName(AfterName.Scan) },
        onEnterCode = { requireName(AfterName.EnterCode) },
        modifier = Modifier
          .align(Alignment.BottomCenter)
          // Measured OUTSIDE the margins + nav-bar inset so the spacer clears the
          // whole dock.
          .onGloballyPositioned { dockHeightPx = it.size.height }
          // The container no longer reserves the nav bar; lift the dock above it here.
          .windowInsetsPadding(stableScreenInsets.only(WindowInsetsSides.Bottom))
          .padding(horizontal = 16.dp)
          .padding(bottom = 12.dp),
      )
    }
    if (showScanner) {
      ScanScreen(
        games = games,
        // The scanner only vouches for the payload's shape; which room it names is the
        // directory's call, so hand back the raw value and resolve it like any other input.
        onCode = { showScanner = false; resolveAndJoin(it) },
        // A scanned legal-page QR: close the camera and open the doc viewer, with
        // the same confirm haptic as a successful join scan.
        onOpenLegalDoc = { url ->
          haptics.performHapticFeedback(HapticFeedbackType.Confirm)
          showScanner = false
          onOpenLegalDoc(url)
        },
        // Close the camera too: left running behind the dialog it would keep
        // decoding and could join mid-keystroke off a QR still in frame.
        onEnterCode = { showScanner = false; codeError = null; showCodeEntry = true },
        onClose = { showScanner = false },
      )
    }
    // The same cover the game host shows while the controller paints, so a join is ONE
    // loading screen from tap to page: this one names no game because resolving is what
    // discovers which one, and the host's picks up the name.
    AnimatedVisibility(visible = joining, enter = fadeIn(), exit = fadeOut(tween(300))) {
      JoiningCover(stringResource(R.string.joining))
    }
  }

  if (showProfile) {
    val gating = afterName != null
    ProfileSheet(
      initial = profile,
      title = stringResource(if (gating) R.string.enter_your_name else R.string.name),
      cta = stringResource(if (gating) R.string.save_and_continue else R.string.save),
      onDismiss = {
        showProfile = false
        afterName = null
      },
      onSave = { saved ->
        ProfileStore.save(context, saved)
        profile = saved
        showProfile = false
        val a = afterName
        afterName = null
        if (a != null) perform(a)
      },
    )
  }

  if (showCodeEntry) {
    CodeEntryDialog(
      loading = codeLoading,
      error = codeError,
      onDismiss = {
        if (!codeLoading) {
          showCodeEntry = false
          codeError = null
        }
      },
      onSubmit = { code ->
        codeError = null
        codeLoading = true
        scope.launch {
          val outcome = resolveJoin(code.trim(), games)
          codeLoading = false
          when (outcome) {
            is JoinOutcome.Success -> {
              showCodeEntry = false
              launchJoin(outcome)
            }
            is JoinOutcome.Failure -> {
              haptics.performHapticFeedback(HapticFeedbackType.Reject)
              codeError = resources.getString(outcome.messageRes)
            }
          }
        }
      },
    )
  }

  infoGame?.let { game ->
    GameInfoSheet(
      game = game,
      onDismiss = { infoGame = null },
      onScan = { infoGame = null; requireName(AfterName.Scan) },
      onEnterCode = { infoGame = null; requireName(AfterName.EnterCode) },
    )
  }
}

// A join action deferred until the player has a name (see requireName).
private sealed interface AfterName {
  data object Scan : AfterName
  data object EnterCode : AfterName
  data class Join(val target: JoinOutcome.Success) : AfterName
}

// Home chrome over the sky: the frosted name chip and About at the top right, the title
// large beneath them (iOS's large navigation title) with the fleet flying beside it.
@Composable
private fun HomeTopBar(profile: Profile, onEditProfile: () -> Unit, onOpenAbout: () -> Unit) {
  Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
    Row(
      Modifier.fillMaxWidth(),
      horizontalArrangement = Arrangement.spacedBy(10.dp, Alignment.End),
      verticalAlignment = Alignment.CenterVertically,
    ) {
      PlayerChip(name = profile.name, onClick = onEditProfile)
      IconButton(
        onClick = onOpenAbout,
        modifier = Modifier.size(44.dp),
        colors = IconButtonDefaults.iconButtonColors(
          containerColor = MaterialTheme.colorScheme.frosted,
          contentColor = MaterialTheme.colorScheme.onSurface,
        ),
      ) {
        Icon(Icons.Outlined.Info, contentDescription = stringResource(R.string.about), Modifier.size(22.dp))
      }
    }
    Text(
      stringResource(R.string.app_name),
      style = MaterialTheme.typography.headlineLarge,
      fontWeight = FontWeight.SemiBold,
      modifier = Modifier.padding(top = 18.dp),
    )
    Text(
      stringResource(R.string.home_subtitle),
      style = MaterialTheme.typography.labelMedium,
      color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
  }
}

// Tactile press feedback shared by the tappable cards: a subtle spring scale-down
// while held, matching iOS's PressableCardButtonStyle.
@Composable
private fun rememberPressScale(interaction: MutableInteractionSource): Float {
  val pressed by interaction.collectIsPressedAsState()
  val scale by animateFloatAsState(
    targetValue = if (pressed) 0.97f else 1f,
    animationSpec = spring(stiffness = Spring.StiffnessMediumLow),
    label = "cardPress",
  )
  return scale
}

// The game-end notice: a high-contrast strip in the rejoin slot. Auto-dismisses after
// 5s (timer in MainNavigation — it must survive this entry being disposed under a
// pushed game host); a tap or a horizontal swipe dismisses it early. Enter/exit mirror
// the rejoin card so the two stack cleanly when both are present.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun GameEndBanner(message: String?, onDismiss: () -> Unit) {
  // Retain the last text so the exit animation still has content after `message` clears.
  var lastMessage by remember { mutableStateOf<String?>(null) }
  LaunchedEffect(message) {
    if (message != null) lastMessage = message
  }

  AnimatedVisibility(
    visible = message != null,
    enter = fadeIn() + scaleIn(initialScale = 0.96f),
    exit = fadeOut() + scaleOut(targetScale = 0.96f),
  ) {
    // Swipe-off is handled by the framework's SwipeToDismissBox. Its state is scoped to
    // this content, which is disposed on exit and recomposed on the next enter, so the
    // swipe resets on its own without any manual reset.
    val dismissState = rememberSwipeToDismissBoxState()
    LaunchedEffect(dismissState.currentValue) {
      if (dismissState.currentValue != SwipeToDismissBoxValue.Settled) onDismiss()
    }
    SwipeToDismissBox(
      state = dismissState,
      backgroundContent = {},   // nothing revealed — the strip just slides away
    ) {
      Surface(
        color = MaterialTheme.colorScheme.inverseSurface,
        contentColor = MaterialTheme.colorScheme.inverseOnSurface,
        shape = MaterialTheme.shapes.medium,
        modifier = Modifier
          .fillMaxWidth()
          .clickable(
            indication = null,
            interactionSource = remember { MutableInteractionSource() },
          ) { onDismiss() },
      ) {
        Text(
          text = lastMessage.orEmpty(),
          modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
          style = MaterialTheme.typography.bodyMedium,
        )
      }
    }
  }
}

/**
 * A room the player can enter right now — the one they just left, or one a display is
 * advertising. The two are the same object to a player, so they are one card; only where
 * the pieces come from differs, which is what [RejoinCard] and [NearbyCard] supply.
 *
 * The game cards' container, so the two sections read as one family. Play under the row
 * carries the sunset on the [primary] room only — the first one — so a second room doesn't
 * put a second primary on screen; the rest get the ghost button. The game's colour lives
 * on the icon and nowhere else: routing it through the card's edge or fill made every
 * HexStacker card near-CTA red (its accent is #FF6B6B beside the sunset), which both read
 * as an alert and spent the one colour that's supposed to mean "this is how you play".
 */
@Composable
private fun RoomCard(
  game: Game,
  title: String,
  roomCode: String,
  /** The display's own label ("Wohnzimmer"). Blank when nothing on the LAN names the room. */
  label: String,
  /** `pbp` — which box the room is on (§6). Null when the URL declared nothing. */
  platform: String?,
  primary: Boolean,
  onClick: () -> Unit,
) {
  val interaction = remember { MutableInteractionSource() }
  val scale = rememberPressScale(interaction)
  val onCard = MaterialTheme.colorScheme.onSurface
  // "Wohnzimmer · Apple TV" — which box, on its own line. Either half may be missing.
  val locator = listOfNotNull(label.ifBlank { null }, deviceName(platform)).joinToString(" · ")
  Card(
    onClick = onClick,
    modifier = Modifier
      .fillMaxWidth()
      .graphicsLayer { scaleX = scale; scaleY = scale },
    interactionSource = interaction,
    shape = MaterialTheme.shapes.large,
    colors = CardDefaults.cardColors(
      containerColor = MaterialTheme.colorScheme.card,
      contentColor = onCard,
    ),
    // As GameCard: by day the hairline is the card's only edge, by night the lifted fill is.
    border = if (MaterialTheme.colorScheme.isDark) null else BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
  ) {
    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
      Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp),
      ) {
        GameIcon(game, tint = onCard)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
          Text(
            cardTitle(title, roomCode, onCard.copy(alpha = 0.55f)),
            style = MaterialTheme.typography.titleMedium,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
          )
          if (locator.isNotBlank()) {
            Text(
              locator,
              style = MaterialTheme.typography.bodyMedium,
              color = onCard.copy(alpha = 0.72f),
              maxLines = 1,
              overflow = TextOverflow.Ellipsis,
            )
          }
        }
      }
      PlayButton(primary, onClick)
    }
  }
}

// The room card's Play: the sunset on the primary room, the ghost button on the rest.
@Composable
private fun PlayButton(primary: Boolean, onClick: () -> Unit) {
  val label = @Composable { Text(stringResource(R.string.join), style = MaterialTheme.typography.titleMedium) }
  val modifier = Modifier.fillMaxWidth().height(48.dp)
  if (primary) {
    SunsetButton(onClick, modifier) { label() }
  } else {
    OutlinedButton(
      onClick = onClick,
      modifier = modifier,
      colors = ButtonDefaults.outlinedButtonColors(
        containerColor = MaterialTheme.colorScheme.ghost,
        contentColor = MaterialTheme.colorScheme.onSurface,
      ),
      border = BorderStroke(1.5.dp, MaterialTheme.colorScheme.ghostLine),
      content = { label() },
    )
  }
}

/**
 * The room just left: its title comes from the controller page itself once captured, so
 * it beats the manifest's curated name.
 *
 * [advert] is the same room as the LAN is currently advertising it, when it still is
 * (`HomeRooms.rejoinAdvert`) — the only source of the room's own NAME, and the freshest
 * source of its platform. Never the only source of that, though: an advertisement is
 * transient — a browser room is advertised only by the phones in it, so it stops naming
 * its box moments after this one leaves — so the platform lives on the room itself.
 */
@Composable
private fun RejoinCard(room: RecentRoom, advert: NearbyRoom? = null, primary: Boolean, onClick: () -> Unit) = RoomCard(
  game = room.game,
  title = room.title ?: room.game.name,
  roomCode = room.roomCode,
  label = advert?.label.orEmpty(),
  platform = advert?.platform ?: room.platform,
  primary = primary,
  onClick = onClick,
)

/** A room a display on this network is advertising (contract §8). */
@Composable
private fun NearbyCard(room: NearbyRoom, primary: Boolean, onClick: () -> Unit) = RoomCard(
  game = room.game,
  title = room.game.name,
  roomCode = room.roomCode,
  label = room.label,
  platform = room.platform,
  primary = primary,
  onClick = onClick,
)

// "HexStacker A3KX9p" — the room code sits with the thing it belongs to, demoted in
// color so the name still leads. One annotated string, so a long name truncates the
// pair as a unit.
private fun cardTitle(name: String, roomCode: String, codeColor: Color) = buildAnnotatedString {
  append(name)
  if (roomCode.isNotBlank()) {
    withStyle(SpanStyle(color = codeColor)) {
      append("  ")
      append(roomCode)
    }
  }
}

// Where discovery currently stands, when it has no room to show for it.
private enum class NearbyStatus {
  // Not granted yet.
  Ask,
  Searching,
  None,
  // Opted in, but no Wi-Fi/Ethernet is up — nothing local to search, so the slot says
  // how to fix that instead of claiming a search happened.
  NoWifi,
  // Refused until the system stopped prompting, which is unrecoverable in-app.
  Denied,
}

// What the TV slot shows when there are no rooms to show.
//
// Ask and denied are one design: a muted info line in the OS's own permission-education
// formula — "To [what you want], allow [the toggle by its system name]" — goal first,
// then the concrete thing to flip, over a button that carries only the verb —
// ask the system, or open Settings once that's the one place that can still answer. Only
// the verb changes between the two. The info line wears the toggle's own system icon —
// the mark the system dialog and the Settings row show — in the muted-status layout, so
// every state of the slot is one icon-plus-line; the button stays bare-verb tonal like
// the info sheet's "Enter code manually", at the same height. Tonal, not the sunset: this
// is one-time setup that vanishes for good once granted, and it must not outshout the
// scan CTA you use every session.
//
// Once granted, searching, not-found and the off-Wi-Fi hint collapse to a muted line — an
// idle home screen shouldn't carry a box announcing that a TV simply isn't switched on.
@Composable
private fun NearbyStatusCard(state: NearbyStatus, onAsk: () -> Unit, onOpenSettings: () -> Unit) {
  if (state == NearbyStatus.Ask || state == NearbyStatus.Denied) {
    val denied = state == NearbyStatus.Denied
    Column(Modifier.fillMaxWidth()) {
      // The toggle's name is bolded rather than quoted; it lives in its own resource
      // (nearby_perm) so the bold span survives translation-driven word order.
      val perm = stringResource(R.string.nearby_perm)
      val hint = stringResource(R.string.nearby_hint, perm)
      StatusLine(
        buildAnnotatedString {
          append(hint)
          val at = hint.indexOf(perm)
          if (at >= 0) addStyle(SpanStyle(fontWeight = FontWeight.Bold), at, at + perm.length)
        },
        icon = R.drawable.ic_nearby_devices,
      )
      Spacer(Modifier.height(8.dp))
      FilledTonalButton(
        onClick = if (denied) onOpenSettings else onAsk,
        modifier = Modifier.fillMaxWidth().height(56.dp),
      ) {
        Text(
          stringResource(if (denied) R.string.nearby_denied else R.string.nearby_allow),
          style = MaterialTheme.typography.titleMedium,
        )
      }
    }
    return
  }
  StatusLine(
    AnnotatedString(
      stringResource(
        when (state) {
          NearbyStatus.Searching -> R.string.nearby_searching
          NearbyStatus.NoWifi -> R.string.nearby_no_wifi
          else -> R.string.nearby_none
        },
      ),
    ),
    icon = if (state == NearbyStatus.NoWifi) R.drawable.ic_wifi_off else R.drawable.ic_nearby,
    showsProgress = state == NearbyStatus.Searching,
  )
}

// The slot's one muted voice — the button's metrics (22dp glyph, titleMedium) so the slot
// doesn't change scale as it moves between offering and reporting; only the muted color
// says "status". Mirrors iOS `statusLine`.
@Composable
private fun StatusLine(text: AnnotatedString, @DrawableRes icon: Int, showsProgress: Boolean = false) {
  Row(
    Modifier.fillMaxWidth().heightIn(min = 48.dp).padding(horizontal = 4.dp),
    verticalAlignment = Alignment.CenterVertically,
    horizontalArrangement = Arrangement.spacedBy(10.dp),
  ) {
    if (showsProgress) {
      CircularProgressIndicator(Modifier.size(22.dp), strokeWidth = 2.5.dp)
    } else {
      Icon(
        painterResource(icon),
        contentDescription = null,
        Modifier.size(22.dp),
        tint = MaterialTheme.colorScheme.onSurfaceVariant,
      )
    }
    Text(
      text,
      style = MaterialTheme.typography.titleMedium,
      color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
  }
}

// The catalog: a heading, then every game — live or coming soon — as the same card.
@Composable
private fun GamesSection(
  games: List<Game>,
  underBar: SnapshotStateMap<String, Boolean>,
  modifier: Modifier = Modifier,
  onOpen: (Game) -> Unit,
) {
  Column(modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
    Column(Modifier.padding(bottom = 2.dp)) {
      SectionTitle(stringResource(R.string.games_title))
      // Path-free: on a TV the game is an app, on a laptop a website.
      Text(
        stringResource(R.string.join_start_game),
        style = MaterialTheme.typography.bodyLarge,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
      )
    }
    games.forEach { game -> GameCard(game, underBar, onOpen) }
  }
}

// The heading each home section opens under.
@Composable
private fun SectionTitle(text: String) {
  Text(text, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
}

// Relative luminance above which the status bar's dark icons beat its white ones:
// Android's dark icons are translucent, so this sits well above the pure-black
// crossover (~0.18).
private const val ICON_FLIP_LUMINANCE = 0.4f

// The language's card: flat, the card fill with one hairline, the poster whole and
// untouched on top, and the name under it with its tag beside it, the player count at
// the right and where it runs below. The whole card is the tap.
@Composable
private fun GameCard(game: Game, underBar: SnapshotStateMap<String, Boolean>, onOpen: (Game) -> Unit) {
  val interaction = remember { MutableInteractionSource() }
  val scale = rememberPressScale(interaction)
  val art = rememberArt(game.art)
  // Whether the art is light where the status bar's icon row crosses this poster; null
  // while the bar is elsewhere (the card body is the theme's own tone) or the art hasn't
  // decoded. Decided in the positioned callback so the card only recomposes on a flip,
  // not on every scroll frame. Root coordinates are window coordinates (edge to edge),
  // so root y = 0 is the top of the screen.
  val barCenterPx = with(LocalDensity.current) { stableScreenInsets.getTop(this) / 2f }
  val latestArt by rememberUpdatedState(art)
  var lightUnderBar by remember { mutableStateOf<Boolean?>(null) }
  DisposableEffect(lightUnderBar) {
    lightUnderBar?.let { underBar[game.id] = it }
    onDispose { underBar.remove(game.id) }
  }
  val muted = MaterialTheme.colorScheme.onSurfaceVariant
  Card(
    onClick = { onOpen(game) },
    modifier = Modifier
      .fillMaxWidth()
      .graphicsLayer { scaleX = scale; scaleY = scale },
    interactionSource = interaction,
    shape = MaterialTheme.shapes.large,
    colors = CardDefaults.cardColors(
      containerColor = MaterialTheme.colorScheme.card,
      contentColor = MaterialTheme.colorScheme.onSurface,
    ),
    // By day the hairline is the card's only edge on the paper; by night the lifted fill is.
    border = if (MaterialTheme.colorScheme.isDark) null else BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
  ) {
    // 16:9 matches the screenshots — a shorter crop would slice the per-player
    // HUD chips in the corners of each quadrant.
    GameArt(
      game,
      art,
      Modifier
        .fillMaxWidth()
        .aspectRatio(16f / 9f)
        .onGloballyPositioned { coords ->
          // positionInRoot, not boundsInRoot: the latter clips to the ancestors, which
          // would fold the part scrolled off the top into the fraction.
          val top = coords.positionInRoot().y
          val height = coords.size.height
          val crossing = if (barCenterPx >= top && barCenterPx < top + height) (barCenterPx - top) / height else null
          lightUnderBar = latestArt?.let { a -> crossing?.let { posterLuminance(a, it) > ICON_FLIP_LUMINANCE } }
        },
    )
    Column(Modifier.padding(start = 14.dp, top = 12.dp, end = 14.dp, bottom = 14.dp)) {
      Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(
          Modifier.weight(1f),
          verticalAlignment = Alignment.CenterVertically,
          horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
          Text(
            game.name,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f, fill = false),
          )
          StatusTag(game)
        }
        // "1–8" with the person glyph standing in for the word "players" (Game.playersRange).
        game.playersRange?.let { range ->
          Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Icon(painterResource(R.drawable.ic_people), contentDescription = null, Modifier.size(18.dp), tint = muted)
            Text(range, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium, color = muted)
          }
        }
      }
      // Where it runs: each live TV app, then the browser host. A game with neither
      // (not out yet) has no row.
      val meta = buildList {
        TV_PLATFORMS.forEach { (id, nameRes) ->
          if (game.tvApps[id] == "live") add(R.drawable.ic_tv to stringResource(nameRes))
        }
        game.displayHost?.let { add(R.drawable.ic_globe to it) }
      }
      if (meta.isNotEmpty()) {
        Row(
          Modifier.padding(top = 6.dp),
          verticalAlignment = Alignment.CenterVertically,
          horizontalArrangement = Arrangement.spacedBy(14.dp),
        ) {
          meta.forEach { (icon, label) ->
            Row(
              Modifier.weight(1f, fill = false),
              verticalAlignment = Alignment.CenterVertically,
              horizontalArrangement = Arrangement.spacedBy(5.dp),
            ) {
              Icon(painterResource(icon), contentDescription = null, Modifier.size(15.dp), tint = muted)
              Text(
                label,
                style = MaterialTheme.typography.bodyMedium,
                color = muted,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
              )
            }
          }
        }
      }
    }
  }
}

// How light a poster is at [fraction] of its height: what the status-bar icons sit on.
private fun posterLuminance(art: Art, fraction: Float): Float =
  art.rowLuminance[(fraction * ART_LUMINANCE_ROWS).toInt().coerceIn(0, ART_LUMINANCE_ROWS - 1)]

// The home sky behind the catalog, scrolling with it. One dusk: lilac at the zenith, peach
// at the horizon, fading into the paper by the first card — with flat white clouds by day;
// by night its afterglow (navy, dusk violet, the sunset's last light at the horizon), with
// the clouds gone and the stars out. The fleet flies beside the large title: the sunset
// balloon leads, sea, gold and dusk follow. Placed in dp from the top of the screen (sky)
// or the bottom of the status bar (the fleet, which keeps station with the title) and
// from the right edge; iOS's SkyBackdrop draws the same sky around its own title.
@Composable
private fun SkyBackdrop(scrolled: () -> Int) {
  val scheme = MaterialTheme.colorScheme
  val dark = scheme.isDark
  val statusTop = with(LocalDensity.current) { stableScreenInsets.getTop(this).toDp() }
  // Moved in the draw phase (graphicsLayer reads the offset there), so scrolling never
  // recomposes it.
  Box(Modifier.fillMaxSize().graphicsLayer { translationY = -scrolled().toFloat() }) {
    Canvas(Modifier.fillMaxSize()) {
      val paperAt = SKY_PAPER_DP.dp.toPx()
      drawRect(
        if (dark) {
          Brush.verticalGradient(
            0f to SkyNight[0], SKY_NIGHT_DUSK_DP / SKY_PAPER_DP to SkyNight[1],
            SKY_NIGHT_GLOW_DP / SKY_PAPER_DP to SkyNight[2], 1f to scheme.background, endY = paperAt,
          )
        } else {
          Brush.verticalGradient(
            0f to SkyLight[0], SKY_HORIZON_DP / SKY_PAPER_DP to SkyLight[1], 1f to scheme.background, endY = paperAt,
          )
        },
      )
      if (dark) {
        for ((x, y, r) in SKY_STARS) {
          drawCircle(scheme.onSurface.copy(alpha = 0.75f), r.dp.toPx(), Offset(x * size.width, y.dp.toPx()))
        }
      } else {
        for (cloud in SKY_CLOUDS) {
          // A puff: a rounded bar with three circles rising from it, on a 200×90 grid.
          val s = cloud.width.dp.toPx() / 200f
          val left = if (cloud.fromRight) size.width + cloud.x.dp.toPx() - cloud.width.dp.toPx() else cloud.x.dp.toPx()
          val top = cloud.y.dp.toPx()
          drawRoundRect(Color.White, Offset(left + 16 * s, top + 52 * s), Size(168 * s, 34 * s), CornerRadius(17 * s))
          drawCircle(Color.White, 30 * s, Offset(left + 62 * s, top + 54 * s))
          drawCircle(Color.White, 38 * s, Offset(left + 106 * s, top + 44 * s))
          drawCircle(Color.White, 24 * s, Offset(left + 150 * s, top + 58 * s))
        }
      }
    }
    val fleet = listOf(
      if (dark) FleetSunsetNight else FleetSunset,
      FleetSea,
      FleetGold,
      if (dark) FleetDuskNight else FleetDusk,
    )
    SKY_FLEET.forEachIndexed { i, (width, end, top) ->
      val brush = Brush.verticalGradient(fleet[i])
      Image(
        painterResource(R.drawable.sky_balloon),
        contentDescription = null,
        modifier = Modifier
          .align(Alignment.TopEnd)
          .padding(top = statusTop + top.dp, end = end.dp)
          .width(width.dp)
          .aspectRatio(SKY_BALLOON_ASPECT)
          // The silhouette becomes a mask for the balloon's gradient.
          .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
          .drawWithContent {
            drawContent()
            drawRect(brush, blendMode = BlendMode.SrcIn)
          },
      )
    }
  }
}

// The sky's stops, in dp from the top of the screen: the horizon (peach), the night's dusk
// violet and its afterglow, and where either sky has become the paper.
private const val SKY_HORIZON_DP = 220f
private const val SKY_NIGHT_DUSK_DP = 140f
private const val SKY_NIGHT_GLOW_DP = 250f
private const val SKY_PAPER_DP = 520f
// x as a fraction of the width, y in dp from the top of the screen, radius dp.
private val SKY_STARS = listOf(
  Triple(0.08f, 40f, 1.2f), Triple(0.31f, 90f, 1f), Triple(0.51f, 30f, 1.3f), Triple(0.77f, 70f, 1f),
  Triple(0.92f, 150f, 1.2f), Triple(0.18f, 190f, 1f), Triple(0.64f, 210f, 1.1f), Triple(0.85f, 300f, 1f),
  Triple(0.10f, 330f, 1.2f), Triple(0.46f, 390f, 1f), Triple(0.15f, 20f, 0.8f), Triple(0.41f, 60f, 1.2f),
  Triple(0.62f, 120f, 0.9f), Triple(0.87f, 30f, 1f), Triple(0.05f, 110f, 1.3f), Triple(0.28f, 150f, 0.8f),
  Triple(0.74f, 160f, 1.1f), Triple(0.95f, 210f, 0.9f), Triple(0.38f, 230f, 1f), Triple(0.21f, 260f, 1.2f),
  Triple(0.56f, 280f, 0.8f), Triple(0.77f, 250f, 1.3f), Triple(0.08f, 370f, 0.9f), Triple(0.33f, 340f, 1.1f),
  Triple(0.67f, 350f, 0.8f), Triple(0.90f, 380f, 1.2f), Triple(0.49f, 410f, 0.9f), Triple(0.95f, 100f, 0.8f),
)
// Clouds: left dp (from the screen's right edge when fromRight), top dp from the top of
// the screen, width dp. One overflows the left edge, one drifts behind the fleet at the
// right — never behind the chips or over the status line below the title.
private class Cloud(val x: Float, val y: Float, val width: Float, val fromRight: Boolean)
private val SKY_CLOUDS = listOf(
  Cloud(-12f, 46f, 118f, fromRight = false), Cloud(-10f, 96f, 150f, fromRight = true), Cloud(118f, 24f, 54f, fromRight = false),
)
// The fleet in colour order (sunset, sea, gold, dusk): width dp, end margin dp, top dp
// below the status bar. The sunset is the biggest; the rest fly smaller and further off.
private val SKY_FLEET = listOf(
  Triple(40f, 48f, 62f), Triple(24f, 104f, 94f), Triple(15f, 20f, 56f), Triple(17f, 5f, 92f),
)
private const val SKY_BALLOON_ASPECT = 58f / 82.43f // res/drawable/sky_balloon.xml's viewport

// The soft edge under the dock, like iOS's soft scroll edge: the list, drawn again from its
// layer at three blur strengths that fade in over overlapping halves of the ramp, so the
// blur grows progressively instead of one blurred copy crossfading over the sharp list (a
// faint double image that reads as a line), under a veil of the paper (blur alone keeps
// the posters saturated and reads as out-of-focus content, not a frosted surface). Every
// ramp is eased, so nothing kinks where it starts or ends. The edge reaches only a little
// above the dock and finishes softening just inside it, so the posters stay sharp until
// they reach the buttons. Below API 31 (no render effects) the list
// fades into the paper instead.
@Composable
private fun DockEdge(list: GraphicsLayer, scrolled: () -> Int, modifier: Modifier) {
  val blurs = List(DOCK_EDGE_BLURS.size) { rememberGraphicsLayer() }
  val masked = List(DOCK_EDGE_BLURS.size) { rememberGraphicsLayer() }
  val background = MaterialTheme.colorScheme.background
  Box(
    modifier
      .fillMaxWidth()
      .drawWithCache {
        val ramp = DOCK_EDGE_RAMP.toPx()
        val veil = easedRamp(background.copy(alpha = 0f), background.copy(alpha = 0.5f), 0f, ramp)
        val fade = easedRamp(background.copy(alpha = 0f), background, 0f, ramp)
        val masks = DOCK_EDGE_BLURS.map { (_, from, to) -> easedRamp(Color.Transparent, Color.Black, from * ramp, to * ramp) }
        onDrawBehind {
          scrolled() // read here so every scroll frame redraws the edge
          if (Build.VERSION.SDK_INT >= 31) {
            // The list layer is the whole viewport; this edge is its bottom slice.
            val above = list.size.height - size.height
            val slice = IntSize(size.width.toInt(), size.height.toInt())
            DOCK_EDGE_BLURS.forEachIndexed { i, (radius, _, _) ->
              val blur = blurs[i]
              blur.record(slice) { translate(top = -above) { drawLayer(list) } }
              blur.renderEffect = BlurEffect(radius.toPx(), radius.toPx(), TileMode.Clamp)
              // The mask's DstIn must cut only this blur, so the two share an offscreen layer.
              val layer = masked[i]
              layer.compositingStrategy = LayerCompositingStrategy.Offscreen
              layer.record(slice) {
                drawLayer(blur)
                drawRect(masks[i], blendMode = BlendMode.DstIn)
              }
              drawLayer(layer)
            }
            drawRect(veil)
          } else {
            drawRect(fade)
          }
        }
      },
  )
}

// A vertical ramp from [from] to [to] between [startY] and [endY], eased (smoothstep) so
// its slope is zero at both ends — a linear ramp shows a line where it stops.
private fun easedRamp(from: Color, to: Color, startY: Float, endY: Float): Brush {
  val steps = 12
  val stops = Array(steps + 1) { i ->
    val t = i / steps.toFloat()
    t to lerp(from, to, t * t * (3 - 2 * t))
  }
  return Brush.verticalGradient(*stops, startY = startY, endY = endY)
}

// How far above the dock the list starts to soften, and over how far it does (so the ramp
// ends half of it inside the dock).
private val DOCK_EDGE_ABOVE = 12.dp
private val DOCK_EDGE_RAMP = 24.dp
// The progressive blur: radius, and where in the ramp (0 = its top, 1 = its end) that
// strength fades in.
private val DOCK_EDGE_BLURS = listOf(
  Triple(2.dp, 0f, 0.5f), Triple(4.dp, 0.25f, 0.75f), Triple(6.dp, 0.5f, 1f),
)

// The dock at the thumb, over the scrolling catalog: scan, and the keyboard for a typed
// code.
@Composable
private fun JoinDock(
  onScan: () -> Unit,
  onEnterCode: () -> Unit,
  modifier: Modifier = Modifier,
) {
  Row(
    modifier.fillMaxWidth(),
    verticalAlignment = Alignment.CenterVertically,
    horizontalArrangement = Arrangement.spacedBy(12.dp),
  ) {
    ScanButton(onScan, Modifier.weight(1f))
    // The ghost button: the card fill with a 1.5dp line, as a circle.
    OutlinedIconButton(
      onClick = onEnterCode,
      modifier = Modifier.size(56.dp),
      colors = IconButtonDefaults.outlinedIconButtonColors(
        containerColor = MaterialTheme.colorScheme.ghost,
        contentColor = MaterialTheme.colorScheme.onSurface,
      ),
      border = BorderStroke(1.5.dp, MaterialTheme.colorScheme.ghostLine),
    ) {
      Icon(
        painterResource(R.drawable.ic_keyboard),
        contentDescription = stringResource(R.string.enter_code_manually),
        Modifier.size(24.dp),
      )
    }
  }
}

// Typed codes resolve via the relay directory (a bare code carries no domain).
// Never auto-uppercases — room codes are case-sensitive base58.
@Composable
private fun CodeEntryDialog(
  loading: Boolean,
  error: String?,
  onSubmit: (String) -> Unit,
  onDismiss: () -> Unit,
) {
  var code by remember { mutableStateOf("") }
  val canSubmit = code.isNotBlank() && !loading
  AlertDialog(
    onDismissRequest = onDismiss,
    title = { Text(stringResource(R.string.enter_room_code)) },
    text = {
      // Focus on open, so the keyboard rises with the dialog. The effect lives in the
      // dialog's own composition, next to the field it focuses.
      val focus = remember { FocusRequester() }
      LaunchedEffect(Unit) { focus.requestFocus() }
      OutlinedTextField(
        value = code,
        onValueChange = { if (it.length <= 16) code = it },
        placeholder = { Text(stringResource(R.string.room_code)) },
        singleLine = true,
        // A Base58 code is not a word: the password layout keeps suggestions,
        // correction and the keyboard's learning out of it (the text stays visible —
        // no visual transformation is applied).
        keyboardOptions = KeyboardOptions(
          keyboardType = KeyboardType.Password,
          capitalization = KeyboardCapitalization.None,
          autoCorrectEnabled = false,
          imeAction = ImeAction.Go,
        ),
        keyboardActions = KeyboardActions(onGo = { if (canSubmit) onSubmit(code) }),
        isError = error != null,
        // Null, not an empty lambda: a present slot reserves its line and opens a gap
        // between the field and the buttons.
        supportingText = error?.let { { Text(it) } },
        modifier = Modifier.fillMaxWidth().focusRequester(focus),
      )
    },
    confirmButton = {
      TextButton(onClick = { onSubmit(code) }, enabled = canSubmit) {
        Text(stringResource(if (loading) R.string.joining else R.string.join))
      }
    },
    dismissButton = {
      TextButton(onClick = onDismiss, enabled = !loading) { Text(stringResource(R.string.cancel)) }
    },
  )
}

// ---------------------------------------------------------------------------
// Previews
//
// The home screen's room-card states in one strip, fed by CardSamples so the ones that
// otherwise need a live room — an Android TV display, a game with no manifest icon, a
// name long enough to truncate — are reachable while editing. The cards are theme
// chrome, so the light/dark pair is checking that they adapt rather than sitting as a
// slab. Mirrored by iOS `MainScreen.swift`; a card change wants both.
//
// GameIcon decodes from assets, which the IDE renderer supplies; a remote-only icon has
// no cache here and falls back to the TV glyph.
// ---------------------------------------------------------------------------

@Preview(name = "Nearby — light", showBackground = true, widthDp = 400)
@Preview(name = "Nearby — dark", showBackground = true, widthDp = 400, uiMode = UI_MODE_NIGHT_YES)
@Composable
private fun NearbyCardsPreview() {
  PreviewStrip {
    NearbyStatusCard(NearbyStatus.Ask, onAsk = {}, onOpenSettings = {})
    NearbyStatusCard(NearbyStatus.Searching, onAsk = {}, onOpenSettings = {})
    NearbyStatusCard(NearbyStatus.None, onAsk = {}, onOpenSettings = {})
    NearbyStatusCard(NearbyStatus.Denied, onAsk = {}, onOpenSettings = {})
    NearbyCard(CardSamples.nearbyFull, primary = true) {}
    NearbyCard(CardSamples.nearbyDeviceOnly, primary = false) {}
    NearbyCard(CardSamples.nearbyLabelOnly, primary = false) {}
    NearbyCard(CardSamples.nearbyBare, primary = false) {}
    NearbyCard(CardSamples.nearbyAndroidTv, primary = false) {}
    NearbyCard(CardSamples.nearbyIconless, primary = false) {}
    NearbyCard(CardSamples.nearbyLongName, primary = false) {}
  }
}

@Preview(name = "Rejoin — light", showBackground = true, widthDp = 400)
@Preview(name = "Rejoin — dark", showBackground = true, widthDp = 400, uiMode = UI_MODE_NIGHT_YES)
@Composable
private fun RejoinCardsPreview() {
  PreviewStrip {
    RejoinCard(CardSamples.rejoinPlain, primary = true) {}
    RejoinCard(CardSamples.rejoinIconless, primary = false) {}
    RejoinCard(CardSamples.rejoinPageTitle, primary = false) {}
    RejoinCard(CardSamples.rejoinNoCode, primary = false) {}
    RejoinCard(CardSamples.rejoinWithDevice, primary = false) {}
    // The room's display is still advertising: its name joins the locator, and its
    // relay-declared platform stands in for a remembered URL that named no box.
    RejoinCard(CardSamples.rejoinPlain, CardSamples.nearbyFull, primary = false) {}
    RejoinCard(CardSamples.rejoinWeb, primary = false) {}
  }
}

// Home's own card spacing and padding, so the previews show the gaps the real screen has.
@Composable
private fun PreviewStrip(content: @Composable ColumnScope.() -> Unit) {
  PaperBalloonTheme {
    Surface {
      Column(
        Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
        content = content,
      )
    }
  }
}
