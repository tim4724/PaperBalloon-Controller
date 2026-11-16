package games.paperballoon.controller.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** CONTRACT.md §13: which install referrers the first launch joins. */
class InstallReferrerTest {

  private val link = "https://hexstacker.com/A3KX9p#fra-1"
  private val installed = 1_800_000_000L

  @Test
  fun joinsOnlyShortlyAfterTheInstall() {
    assertEquals(link, referrerJoinLink(link, installed, installed + 30 * 60))
    assertNull(referrerJoinLink(link, installed, installed + 30 * 60 + 1))
    // Play reports no install time as 0.
    assertNull(referrerJoinLink(link, 0, installed))
  }

  @Test
  fun ignoresAnythingButALink() {
    assertNull(referrerJoinLink("utm_source=google-play&utm_medium=organic", installed, installed))
    assertNull(referrerJoinLink(null, installed, installed))
  }
}
