package games.paperballoon.controller.baselineprofile

import androidx.benchmark.macro.MacrobenchmarkScope
import androidx.benchmark.macro.junit4.BaselineProfileRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.uiautomator.By
import androidx.test.uiautomator.Until
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

private const val PACKAGE = "games.paperballoon.controller"

/**
 * Records the launcher's hot paths for the baseline profile: cold start to the home
 * catalog, a scroll through the posters, then the sheets most sessions open — a game's
 * info sheet (trailer), and the two keyboard sheets: the name sheet every player fills
 * in first and the room-code sheet. That covers Activity/Compose init, manifest parse,
 * sky + catalog composition, art decode, nearby discovery and the sheets, without flows
 * that need a live room (join/game host) or hardware (scanner).
 */
@RunWith(AndroidJUnit4::class)
class BaselineProfileGenerator {

  @get:Rule
  val rule = BaselineProfileRule()

  /**
   * Startup profile (feeds dexLayoutOptimization): launch-to-first-frame ONLY, no
   * scroll — dex layout should cluster exactly the classes cold start touches, and
   * a broader journey would dilute that. Merged with [generate]'s output; the
   * journey's rules still land in the baseline profile for AOT.
   */
  @Test
  fun startup() {
    rule.collect(packageName = PACKAGE, includeInStartupProfile = true) {
      prepareApp()
      pressHome()
      startActivityAndWait()
    }
  }

  @Test
  fun generate() {
    rule.collect(packageName = PACKAGE) {
      prepareApp()
      pressHome()
      startActivityAndWait()
      device.wait(Until.hasObject(By.text("HexStacker")), 10_000)

      // Scroll the catalog down and back — the catalog is up once the wait above
      // returns; the swipe itself exercises art decode + draw.
      val w = device.displayWidth
      val h = device.displayHeight
      device.swipe(w / 2, h * 3 / 4, w / 2, h / 4, 20)
      device.waitForIdle()
      device.swipe(w / 2, h / 4, w / 2, h * 3 / 4, 20)
      device.waitForIdle()

      // Game info sheet, long enough for the trailer to start playing.
      val scanStep = By.text("Scan the room code it shows.")
      device.findObject(By.text("HexStacker"))?.click()
      device.wait(Until.hasObject(scanStep), 5_000)
      Thread.sleep(3_000)
      device.pressBack()
      device.wait(Until.gone(scanStep), 5_000)

      // Name sheet: the player chip beside About, whatever name it shows. Saving one also
      // takes the code step below to the code sheet rather than the name gate a
      // nameless install shows first.
      val about = device.findObject(By.desc("About")).visibleBounds
      device.findObjects(By.clickable(true))
        .first { it.visibleBounds.right < about.left && it.visibleBounds.centerY() in about.top..about.bottom }
        .click()
      val save = By.text("Save")
      device.wait(Until.hasObject(save), 5_000)
      device.waitForIdle()
      device.findObject(By.clazz("android.widget.EditText")).text = "Player"
      device.findObject(save).click()
      device.wait(Until.gone(save), 5_000)
      device.waitForIdle()

      // Room-code sheet: the keyboard button beside Scan code. Settle first so the
      // sheet and keyboard animations are recorded; Back may only drop the IME first,
      // so press until the sheet is gone.
      val hint = By.text("Start a game on your TV or in your browser, then enter the code it shows.")
      device.findObject(By.desc("Enter code manually"))?.click()
      device.wait(Until.hasObject(hint), 5_000)
      device.waitForIdle()
      repeat(2) {
        if (device.hasObject(hint)) {
          device.pressBack()
          device.waitForIdle()
        }
      }
    }
  }

  /**
   * English, so the journey's text selectors match whatever locale the emulator runs;
   * Local Network granted, so home takes the discovery path most sessions take rather
   * than showing the one-time ask.
   */
  private fun MacrobenchmarkScope.prepareApp() {
    device.executeShellCommand("cmd locale set-app-locales $PACKAGE --locales en-US")
    device.executeShellCommand("pm grant $PACKAGE android.permission.ACCESS_LOCAL_NETWORK")
  }
}
