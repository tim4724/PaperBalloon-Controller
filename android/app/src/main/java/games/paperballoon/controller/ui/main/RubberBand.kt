package games.paperballoon.controller.ui.main

import androidx.compose.animation.core.SpringSpec
import androidx.compose.animation.core.animate
import androidx.compose.animation.core.spring
import androidx.compose.foundation.OverscrollEffect
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.unit.Velocity
import kotlin.math.abs
import kotlin.math.sign
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

/**
 * The home list's ends as on iOS, in place of Android's stretch: pulled past either end,
 * the list follows the finger ever more stiffly and springs back when let go, and a fling
 * that hits an end bounces. A stretch only distorts the list; a band moves it, so a
 * pull-down shows the sky above the screen (SkyBackdrop's hidden sky).
 *
 * [offset] is how far the list stands off its end, in px, down positive: read it in the
 * layout or draw phase. [extent], the viewport's height, sets how stiff the band gets.
 *
 * As UIScrollView does it: the band keeps the pull, how far the finger or a fling has
 * carried the list past its end, and shows it through the band's give, so the further
 * out, the less the list moves. The spring back works on the pull too, so a hard fling's
 * overshoot rounds off at the top rather than snapping out.
 */
@Stable
internal class RubberBand(private val scope: CoroutineScope) : OverscrollEffect {
  private var pull by mutableFloatStateOf(0f)
  var extent = 0f
  private var settle: Job? = null

  val offset: Float
    get() = if (extent > 0f) sign(pull) * (1 - 1 / (abs(pull) * BAND_GIVE / extent + 1)) * extent else 0f

  override val isInProgress: Boolean get() = pull != 0f

  override fun applyToScroll(delta: Offset, source: NestedScrollSource, performScroll: (Offset) -> Offset): Offset {
    // Only a finger pulls the band; a fling reaching an end bounces in applyToFling.
    if (source != NestedScrollSource.UserInput) return performScroll(delta)
    settle?.cancel()
    var left = delta.y
    // Pushed back towards the end, the band gives way before the list scrolls.
    if (pull != 0f && sign(left) != sign(pull)) {
      val back = if (abs(left) > abs(pull)) -pull else left
      pull += back
      left -= back
    }
    left -= performScroll(Offset(0f, left)).y
    pull += left
    return delta
  }

  override suspend fun applyToFling(velocity: Velocity, performFling: suspend (Velocity) -> Velocity) {
    settle?.cancel()
    if (pull != 0f) {
      // Let go off the end, it springs back, taking a fling further out with it; the list
      // gets no fling of its own (but must be asked, once). The finger moved the pull, so
      // its speed is the pull's.
      performFling(Velocity.Zero)
      return springBack(if (sign(velocity.y) == sign(pull)) velocity.y else 0f, BAND_SPRING)
    }
    // A fling that hits an end runs on into the band at the speed it arrived with, as on
    // iOS, and a stiffer band slows it: one motion, without running far. performFling
    // answers what it used; at the end the list moves BAND_GIVE of the pull's speed.
    val left = velocity.y - performFling(velocity).y
    if (left != 0f) springBack(left / BAND_GIVE, BOUNCE_SPRING)
  }

  private fun springBack(velocity: Float, spring: SpringSpec<Float>) {
    settle = scope.launch {
      animate(pull, 0f, velocity, spring) { value, _ -> pull = value }
    }
  }
}

@Composable
internal fun rememberRubberBand(): RubberBand {
  val scope = rememberCoroutineScope()
  return remember(scope) { RubberBand(scope) }
}

// How much of a pull the band gives at its end, and its spring back: settled in about half
// a second, as UIScrollView's. A fling's bounce is over-damped, so it runs only a short way
// out and takes its time coming back, settling in about 0.65 s.
private const val BAND_GIVE = 0.55f
private val BAND_SPRING = spring<Float>(dampingRatio = 1f, stiffness = 100f)
private val BOUNCE_SPRING = spring<Float>(dampingRatio = 1.5f, stiffness = 144f)
