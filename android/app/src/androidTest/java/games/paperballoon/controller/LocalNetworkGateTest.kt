package games.paperballoon.controller

import android.os.Build
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import games.paperballoon.controller.data.clearLocalNetworkAsked
import games.paperballoon.controller.data.localNetworkPermissionGranted
import java.util.regex.Pattern
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeFalse
import org.junit.Assume.assumeTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * CONTRACT.md §8's Android wait, end to end through the contract test controller: with
 * Nearby devices unanswered the page loads without a dialog, its first
 * `setLocalDescription` brings the dialog up and waits for it, and either answer lets the
 * call through.
 *
 * It needs the permission ungranted when the app starts, and revoking it kills the app —
 * this process — so the run has to begin that way: store-screenshots.yml's API 37 job
 * revokes it, then instruments this class alone. Anywhere else it skips: below API 37,
 * where nothing is gated, and after a grant, ContractTest's seed included.
 */
@RunWith(AndroidJUnit4::class)
class LocalNetworkGateTest {

  @get:Rule val compose = createEmptyComposeRule()

  private val context get() = InstrumentationRegistry.getInstrumentation().targetContext

  private val device get() = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())

  @Before fun seed() {
    assumeTrue("nothing is gated below API 37", Build.VERSION.SDK_INT >= 37)
    assumeFalse("Nearby devices is already granted", localNetworkPermissionGranted(context))
    // A stale "asked" would read the re-askable permission as locked, and nothing would wait.
    clearLocalNetworkAsked(context)
    // As seedDevice: the in-game host hides the system bars.
    shell("settings put secure immersive_mode_confirmations confirmed")
  }

  @Test fun setLocalDescriptionWaitsForTheDialog() {
    compose.inContractPage { page ->
      val anyButton = dialogButton("permission_(allow|deny)_button")
      assertFalse("asked before the page needed the LAN", device.hasObject(anyButton))
      page.offer()
      page.answer("permission_deny_button")
      page.awaitOffered()
      assertFalse("granted", localNetworkPermissionGranted(context))
      // Answered: the page's later calls pass straight through.
      page.offer()
      page.awaitOffered()
    }
    // One deny leaves the permission askable, so the next page waits again.
    compose.inContractPage { page ->
      page.offer()
      page.answer("permission_allow_button")
      page.awaitOffered()
      assertTrue("not granted", localNetworkPermissionGranted(context))
    }
  }

  /** A permission dialog button by its id, whichever package the system dialog comes from. */
  private fun dialogButton(id: String) = By.res(Pattern.compile(".*:id/$id"))

  /** Starts an offer the way a game opens WebRTC. */
  private fun ActivityScenario<MainActivity>.offer() {
    evalJs(
      """
      (() => {
        window.__offer = 'waiting';
        const pc = new RTCPeerConnection();
        pc.createDataChannel('lan');
        pc.createOffer()
          .then((offer) => pc.setLocalDescription(offer))
          .then(() => { window.__offer = 'set'; }, (e) => { window.__offer = String(e); });
      })()
      """,
    )
  }

  /** Answers the system dialog, which the offer must be waiting on. */
  private fun ActivityScenario<MainActivity>.answer(id: String) {
    val button = dialogButton(id)
    // Not device.wait: the ask takes a recomposition, and under the compose rule frames only
    // run while the test waits through it.
    compose.waitUntil(TIMEOUT) { device.hasObject(button) }
    assertEquals("not held while the dialog is up", "waiting", evalJs("window.__offer"))
    device.findObject(button).click()
  }

  private fun ActivityScenario<MainActivity>.awaitOffered() {
    compose.waitUntil(TIMEOUT) { evalJs("window.__offer") != "waiting" }
    assertEquals("set", evalJs("window.__offer"))
  }

  private companion object {
    const val TIMEOUT = 15_000L
  }
}
