package games.paperballoon.controller.data

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * Runs the shared cases in tests/join-resolver.json — the iOS port runs the same file
 * (JoinResolverTests.swift). Robolectric only for android.net.Uri, which the resolver parses with.
 */
@RunWith(RobolectricTestRunner::class)
class JoinResolverTest {

  // tests/ is on the unit-test resource path (app/build.gradle.kts).
  private val cases = JSONObject(javaClass.getResource("/join-resolver.json")!!.readText())

  private val games = cases.getJSONArray("games").objects().map { g ->
    Game(
      id = g.getString("id"),
      name = g.getString("id"),
      status = "live",
      accentColor = DefaultAccent,
      art = null,
      controllerBaseUrl = null,
      hosts = g.getJSONArray("hosts").let { h -> List(h.length()) { h.getString(it) } },
    )
  }

  @Test
  fun resolve() {
    for (case in cases.getJSONArray("resolve").objects()) {
      val input = case.getString("input")
      val outcome = JoinResolver.resolve(input, games)
      if (case.optBoolean("reject")) {
        assertTrue("$input: expected a rejection, got $outcome", outcome is JoinOutcome.Failure)
      } else {
        val success = outcome as? JoinOutcome.Success
          ?: throw AssertionError("$input: expected a join, got $outcome")
        assertEquals(input, case.getString("game"), success.game.id)
        assertEquals(input, case.getString("room"), success.roomCode)
        assertEquals(input, input.trim(), success.joinUrl)
      }
    }
  }

  @Test
  fun originlessCode() {
    for (case in cases.getJSONArray("originlessCode").objects()) {
      val input = case.getString("input")
      val expected = if (case.isNull("code")) null else case.getString("code")
      assertEquals(input, expected, originlessCode(input))
    }
  }

  private fun JSONArray.objects() = List(length()) { getJSONObject(it) }
}
