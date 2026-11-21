package games.paperballoon.controller

import android.content.res.Configuration
import android.net.Uri
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.net.ServerSocket
import java.util.Locale
import org.junit.After
import org.junit.Assume.assumeTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * The Play listing's app screenshots, on the 1080×1920 `ci_api35` AVD (Play rejects phone
 * shots longer than 2:1). Run by `tools/store_screenshots.py`, which passes the instrumentation
 * arguments below, keeps the room alive on the relay and writes the files into `store/`;
 * skipped otherwise, so CI never runs it.
 *
 *   listingShots      the shots to take, comma-separated: game-page, tiny-track, home-nearby
 *   listingLocale     the app's language: en or de
 *   listingRoomCode   the script's room (`fake_room.py`), which this test advertises on the
 *                     LAN itself: the emulator doesn't see the Mac's mDNS
 *   listingRoomLabel  the room's label, URL-encoded
 */
@RunWith(AndroidJUnit4::class)
class ListingScreenshotTest {

  @get:Rule val compose = createEmptyComposeRule()

  private val args = InstrumentationRegistry.getArguments()
  private val appContext get() = InstrumentationRegistry.getInstrumentation().targetContext
  private val language get() = args.getString("listingLocale") ?: "en"

  /** The app's strings in the listing's language, whatever the test process runs in. */
  private fun str(id: Int): String {
    val config = Configuration(appContext.resources.configuration).apply { setLocale(Locale.forLanguageTag(language)) }
    return appContext.createConfigurationContext(config).getString(id)
  }

  @Before
  fun setUp() {
    assumeTrue("run by tools/store_screenshots.py", args.getString("listingShots") != null)
    seedDevice()
    // The per-app language goes with the uninstall after the run.
    shell("cmd locale set-app-locales ${appContext.packageName} --locales $language")
  }

  @After
  fun resetDeviceState() {
    shell("cmd uimode night no")
    shell("am broadcast -a com.android.systemui.demo -e command exit")
  }

  @Test
  fun listing() {
    val shots = args.getString("listingShots")!!.split(",")
    if ("game-page" in shots) gamePage()
    if ("tiny-track" in shots) tinyTrack()
    if ("home-nearby" in shots) homeNearby()
  }

  /** HexStacker's game sheet, dark, with its trailer playing. */
  private fun gamePage() {
    shell("cmd uimode night yes")
    Thread.sleep(1_000)
    applyDemoStatusBar()
    ActivityScenario.launch(MainActivity::class.java).use {
      waitForText("HexStacker")
      compose.onNodeWithText("HexStacker").performClick()
      waitForText(str(R.string.play_step_scan))
      // The trailer starts after a delay on the compose clock, which Thread.sleep
      // alone doesn't advance.
      repeat(16) {
        compose.waitForIdle()
        Thread.sleep(500)
      }
      compose.screenshot(SHOT_DIR, "game-page")
    }
    shell("cmd uimode night no")
  }

  /** Tiny Track's car picker (its own preview harness), landscape. */
  private fun tinyTrack() {
    applyDemoStatusBar()
    compose.inGamePage(TINY_TRACK_URL, landscape = true) {
      Thread.sleep(4_000) // the 3D car previews
      compose.screenshot(SHOT_DIR, "tiny-track")
    }
  }

  /** Home with a room on the TV nearby, advertised as a display would (CONTRACT §8). */
  private fun homeNearby() {
    val label = Uri.decode(args.getString("listingRoomLabel")!!)
    val nsd = appContext.getSystemService(NsdManager::class.java)
    val socket = ServerSocket(0)
    val advert = NsdServiceInfo().apply {
      serviceName = "$label · Paper Balloon"
      serviceType = "_paperballoon._tcp."
      port = socket.localPort
      setAttribute("c", args.getString("listingRoomCode")!!)
    }
    val registration = object : NsdManager.RegistrationListener {
      override fun onServiceRegistered(info: NsdServiceInfo) {}
      override fun onRegistrationFailed(info: NsdServiceInfo, errorCode: Int) {}
      override fun onServiceUnregistered(info: NsdServiceInfo) {}
      override fun onUnregistrationFailed(info: NsdServiceInfo, errorCode: Int) {}
    }
    nsd.registerService(advert, NsdManager.PROTOCOL_DNS_SD, registration)
    try {
      applyDemoStatusBar()
      ActivityScenario.launch(MainActivity::class.java).use {
        compose.waitUntil(timeoutMillis = 30_000) {
          compose.onAllNodesWithText(label, substring = true).fetchSemanticsNodes().isNotEmpty()
        }
        repeat(6) { // the card's arrival, the balloons settling
          compose.waitForIdle()
          Thread.sleep(500)
        }
        compose.screenshot(SHOT_DIR, "home-nearby")
      }
    } finally {
      nsd.unregisterService(registration)
      socket.close()
    }
  }

  private fun waitForText(text: String) {
    compose.waitUntil(timeoutMillis = 10_000) {
      compose.onAllNodesWithText(text).fetchSemanticsNodes().isNotEmpty()
    }
  }

  private companion object {
    const val SHOT_DIR = "paperballoon-listing"
    const val TINY_TRACK_URL = "https://tinytrack.paperballoon.games/A3KX9p?scenario=lobby-host&color=0"
  }
}
