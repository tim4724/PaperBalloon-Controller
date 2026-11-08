package games.paperballoon.controller

import android.content.Intent
import android.content.res.Configuration
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextClearance
import androidx.compose.ui.test.performTextInput
import androidx.core.net.toUri
import androidx.core.view.WindowCompat
import androidx.test.core.app.ActivityScenario
import androidx.test.espresso.Espresso
import androidx.test.espresso.action.ViewActions
import androidx.test.espresso.matcher.RootMatchers.isDialog
import androidx.test.espresso.matcher.ViewMatchers.isRoot
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.webkit.WebViewCompat
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.json.JSONObject
import org.json.JSONTokener
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * The launcher's half of CONTRACT.md, end to end, through the contract test controller
 * (the site repo's controller-test.html, served at [PAGE]). Each test opens the page in the
 * game host and presses the page's own buttons, so every call crosses the real bridge,
 * then asserts both ends: the page's readouts and what the launcher did with its UI and
 * window. Only the page needs network, like StoreScreenshotTest's in-game step: a
 * paperballoon.games subdomain loads verbatim (JoinResolver), so no room, relay or display
 * is involved.
 *
 * §4–5 assert whichever path the device's WebView takes ([legacyWebView]); CI's emulator
 * takes the legacy one (store-screenshots.yml).
 */
@RunWith(AndroidJUnit4::class)
class ContractTest {

  @get:Rule val compose = createEmptyComposeRule()

  private val context get() = InstrumentationRegistry.getInstrumentation().targetContext

  private fun str(id: Int): String = context.getString(id)

  @Before fun seed() = seedDevice()

  /** Older than Chromium 136, which can't report system bars to the page (§5). */
  private fun legacyWebView() =
    (WebViewCompat.getCurrentWebViewPackage(context)?.versionName?.substringBefore('.')?.toIntOrNull() ?: 0) < 136

  /** §1–2: the page reads the launcher's name, and a rename in the launcher's sheet reaches it. */
  @Test fun renameGoesThroughTheLauncherSheet() = inGame {
    awaitText("#name", "\"$PLAYER_NAME\"")
    click("#rename")
    awaitNameSheet()
    compose.onNode(hasSetTextAction()).apply {
      performTextClearance()
      performTextInput(NEW_NAME)
    }
    compose.onNodeWithText(str(R.string.save)).performClick()
    awaitText("#name", "\"$NEW_NAME\"")
  }

  /** §2: back dismisses the sheet (editName resolves null) and never reaches the page,
   *  whose `leave` mode would otherwise close the game. */
  @Test fun dismissedSheetResolvesNull() = inGame {
    click("#rename")
    awaitNameSheet()
    // Aimed at the sheet's own dialog window: its text field can be in the tree before
    // that window has focus, and an untargeted pressBack then picks the activity's
    // window and waits for focus it never gets.
    Espresso.onView(isRoot()).inRoot(isDialog()).perform(ViewActions.pressBack())
    awaitLog("editName → null")
    assertTrue("left the game", hosting())
  }

  /** §3 */
  @Test fun leaveGoesHome() = inGame {
    click("#leave")
    awaitHome()
  }

  /** §3: the first exit wins, here gameEnded, so home shows its message. */
  @Test fun gameEndedBeatsALaterLeave() = inGame {
    click("#endfirst")
    awaitHome()
    compose.onNodeWithText(str(R.string.game_end_room_full)).assertIsDisplayed()
  }

  /** §4: the status-bar icons follow the page's color-scheme meta, live: light icons (a
   *  dark bar) over a dark page. Under a legacy WebView the bar sits on the launcher's own
   *  surface instead (§5), so it follows the system mode. */
  @Test fun colorSchemeSetsStatusBarIcons() = inGame {
    val systemLight =
      (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) != Configuration.UI_MODE_NIGHT_YES
    fun awaitBar(pageLight: Boolean) = awaitLightStatusBar(if (legacyWebView()) systemLight else pageLight)
    awaitBar(false) // the page opens dark
    theme("light")
    awaitBar(true)
    theme("dark")
    awaitBar(false)
    theme("bare") // no meta reads as light
    awaitBar(true)
  }

  /** §5: the page covers the whole screen and env(safe-area-inset-top) is the status bar.
   *  A legacy WebView can't report the bars, so the page is kept below them and reads 0. */
  @Test fun pageCoversTheScreenWithRealInsets() = inGame {
    if (legacyWebView()) {
      awaitText("#env", "0px / 0px / 0px / 0px")
      assertTrue("page under the status bar", webViewTop() > 0)
    } else {
      compose.waitUntil(TIMEOUT) { (text("#env")?.substringBefore("px")?.toFloatOrNull() ?: 0f) > 0f }
      assertEquals("page below the screen's top", 0, webViewTop())
    }
  }

  /** §9: every page load starts at `leave`. */
  @Test fun backLeavesByDefault() = inGame {
    Espresso.pressBackUnconditionally()
    awaitHome()
  }

  /** §9: in `page` mode a back asks the page, and only a literal true keeps the player. */
  @Test fun backInPageModeAsksThePage() = inGame {
    click("[data-mode=page]")
    click("[data-back=consume]")
    Espresso.pressBackUnconditionally()
    awaitText("#backs", "1")
    compose.waitForIdle()
    assertTrue("left the game", hosting())
    click("[data-back=decline]")
    Espresso.pressBackUnconditionally()
    awaitHome()
  }

  /** §9 */
  @Test fun backOffDoesNothing() = inGame {
    click("[data-mode=off]")
    Espresso.pressBackUnconditionally()
    compose.waitForIdle()
    assertTrue("left the game", hosting())
  }

  /** §10: only the literal 'landscape' turns; anything else is portrait again. */
  @Test fun setOrientationTurnsAndResets() = inGame {
    click("[data-orient=landscape]")
    awaitOrientation(Configuration.ORIENTATION_LANDSCAPE)
    awaitText("#orient", "landscape")
    click("[data-orient=nonsense]")
    awaitOrientation(Configuration.ORIENTATION_PORTRAIT)
    awaitText("#orient", "portrait")
  }

  /** Opens [PAGE] the way an App Link does and runs [body] once its script is up. */
  private fun inGame(body: Page.() -> Unit) {
    val intent = Intent(Intent.ACTION_VIEW, PAGE.toUri(), context, MainActivity::class.java)
    ActivityScenario.launch<MainActivity>(intent).use { scenario ->
      Page(scenario).apply {
        compose.waitUntil(PAGE_LOAD_TIMEOUT) { text("#mode") == "launcher shell" }
        body()
      }
    }
  }

  private inner class Page(private val scenario: ActivityScenario<MainActivity>) {

    /** Evaluates [script] in the game host's page; its JSON result, or null when no game is open. */
    fun js(script: String): Any? {
      val done = CountDownLatch(1)
      var result: String? = null
      scenario.onActivity { activity ->
        val webView = activity.window.decorView.findWebView()
        if (webView == null) {
          done.countDown()
        } else {
          webView.evaluateJavascript(script) {
            result = it
            done.countDown()
          }
        }
      }
      assertTrue("no answer from the page: $script", done.await(10, TimeUnit.SECONDS))
      return result?.let { JSONTokener(it).nextValue() }?.takeUnless { it == JSONObject.NULL }
    }

    fun text(selector: String) = js("document.querySelector('$selector')?.textContent ?? null") as? String

    fun click(selector: String) {
      js("document.querySelector('$selector').click()")
    }

    fun theme(label: String) {
      js("[...document.querySelectorAll('#themes button')].find((b) => b.textContent === '$label').click()")
    }

    fun hosting() = withActivity { it.window.decorView.findWebView() != null }

    fun awaitText(selector: String, expected: String) =
      compose.waitUntil(TIMEOUT) { text(selector) == expected }

    fun awaitLog(line: String) = compose.waitUntil(TIMEOUT) { text("#log")?.contains(line) == true }

    fun awaitNameSheet() =
      compose.waitUntil(TIMEOUT) { compose.onAllNodes(hasSetTextAction()).fetchSemanticsNodes().isNotEmpty() }

    fun awaitHome() = compose.waitUntil(TIMEOUT) {
      !hosting() && compose.onAllNodesWithText(str(R.string.games_title)).fetchSemanticsNodes().isNotEmpty()
    }

    /** A light status bar is one with dark icons. */
    fun awaitLightStatusBar(light: Boolean) = compose.waitUntil(TIMEOUT) {
      withActivity { WindowCompat.getInsetsController(it.window, it.window.decorView).isAppearanceLightStatusBars } == light
    }

    fun webViewTop() = withActivity { activity ->
      IntArray(2).also { activity.window.decorView.findWebView()!!.getLocationOnScreen(it) }[1]
    }

    fun awaitOrientation(orientation: Int) =
      compose.waitUntil(TIMEOUT) { withActivity { it.resources.configuration.orientation } == orientation }

    private fun <T> withActivity(block: (MainActivity) -> T): T {
      var result: Result<T>? = null
      scenario.onActivity { result = runCatching { block(it) } }
      return result!!.getOrThrow()
    }
  }

  private companion object {
    // Any build reaches the deployed page through this App Link (the site repo's README,
    // "Reaching it from the app"): the 6-character path is what the intent filter claims.
    const val PAGE = "https://test.paperballoon.games/PBTEST"
    const val NEW_NAME = "Sam"
    const val TIMEOUT = 15_000L
    const val PAGE_LOAD_TIMEOUT = 30_000L
  }
}
