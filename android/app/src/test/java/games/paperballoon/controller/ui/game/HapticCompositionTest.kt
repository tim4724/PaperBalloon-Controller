package games.paperballoon.controller.ui.game

import android.os.VibrationEffect.Composition
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * Runs the shared cases in tests/haptic-composition.json — the iOS port runs the same file
 * (HapticCompositionTests.swift). Robolectric only because GameHaptics' companion builds
 * AudioAttributes.
 */
@RunWith(RobolectricTestRunner::class)
class HapticCompositionTest {

  // tests/ is on the unit-test resource path (app/build.gradle.kts).
  private val cases = JSONObject(javaClass.getResource("/haptic-composition.json")!!.readText())

  @Test
  fun parseComposition() {
    for (case in cases.getJSONArray("cases").objects()) {
      val input = if (case.isNull("input")) null else case.getString("input")
      val expected = case.getJSONArray("steps").let { s ->
        List(s.length()) { s.getJSONArray(it).let { step -> Triple(step.getString(0), step.getDouble(1), step.getLong(2)) } }
      }
      val actual = GameHaptics.parseComposition(input)
      assertEquals("$input: step count", expected.size, actual.size)
      expected.zip(actual).forEachIndexed { i, (want, got) ->
        val at = "$input, step $i"
        assertEquals(at, PRIMITIVE_IDS.getValue(want.first), got.primitive.id)
        assertEquals(at, want.second, got.scale.toDouble(), 1e-6)
        assertEquals(at, want.third, got.delayMillis)
      }
    }
  }

  private fun JSONArray.objects() = List(length()) { getJSONObject(it) }

  private companion object {
    val PRIMITIVE_IDS = mapOf(
      "click" to Composition.PRIMITIVE_CLICK,
      "tick" to Composition.PRIMITIVE_TICK,
      "low_tick" to Composition.PRIMITIVE_LOW_TICK,
      "thud" to Composition.PRIMITIVE_THUD,
      "spin" to Composition.PRIMITIVE_SPIN,
      "quick_rise" to Composition.PRIMITIVE_QUICK_RISE,
      "slow_rise" to Composition.PRIMITIVE_SLOW_RISE,
      "quick_fall" to Composition.PRIMITIVE_QUICK_FALL,
    )
  }
}
