package games.paperballoon.controller.ui.main

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathOperation
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import games.paperballoon.controller.R
import games.paperballoon.controller.theme.FleetDusk
import games.paperballoon.controller.theme.FleetGold
import games.paperballoon.controller.theme.FleetSea
import games.paperballoon.controller.theme.FleetSunset
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * What tows the hidden sky's "Made with ♥" banner, picked at random once a launch: the
 * blimp or the plane by day, the rocket or the saucer by night. Drawn like the fleet: one
 * silhouette over a fleet gradient, its panels parted by thin gaps. iOS: SkyCraft.swift.
 */
internal enum class SkyCraft(
  /** How fast it flies right, in dp a second. */
  val speed: Float,
  /** Its width in dp; the height follows from the art's box, 100 units wide, nose to the right. */
  val width: Float,
  val unitHeight: Float,
  /** Where the rope ties on, as fractions of its size. It tilts about this point, so the rope stays on. */
  val towX: Float,
  val towY: Float,
  val colors: List<Color>,
  val night: Boolean,
) {
  Blimp(20f, 64f, 40f, 0.14f, 16.5f / 40, FleetDusk, night = false),
  Plane(34f, 60f, 42f, 0.16f, 18f / 42, FleetSunset, night = false),
  Rocket(44f, 66f, 40f, 0.28f, 0.5f, FleetGold, night = true),
  Saucer(26f, 54f, 46f, 0.03f, 24f / 46, FleetSea, night = true);

  val height: Float get() = width * unitHeight / 100

  /** Up and down, in dp, [t] seconds into its flight: the whole tow rises and falls. */
  fun bob(t: Float): Float = when (this) {
    Blimp -> 3 * sin(t * TWO_PI / 9)
    Plane -> 2 * sin(t * TWO_PI / 4)
    Rocket -> 1 * sin(t * TWO_PI / 0.7f)
    Saucer -> 3 * sin(t * TWO_PI / 2.5f)
  }

  /** The craft's own lean in degrees, about its tow point. */
  fun tilt(t: Float): Float = when (this) {
    Blimp -> 1.5f * sin(t * TWO_PI / 9 + HALF_PI)
    Plane -> 2 * sin(t * TWO_PI / 4 + HALF_PI)
    Rocket -> 0f
    Saucer -> 5 * sin(t * TWO_PI / 1.7f)
  }
}

/** A craft with the banner trailing behind it on its rope; [flight] is its seconds of flight, read in the draw phase. */
@Composable
internal fun TowedBanner(craft: SkyCraft, flight: () -> Float, modifier: Modifier = Modifier) {
  val rope = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)
  Layout(
    content = {
      Text(
        stringResource(R.string.made_with_love),
        color = FleetSunset[0],
        fontSize = 10.sp,
        lineHeight = 12.sp,
        fontWeight = FontWeight.SemiBold,
        modifier = Modifier
          .background(Color.White, RoundedCornerShape(4.dp))
          .padding(horizontal = 7.dp, vertical = 3.dp),
      )
      Box(Modifier.background(rope))
      Spacer(
        Modifier
          .graphicsLayer {
            rotationZ = craft.tilt(flight())
            transformOrigin = TransformOrigin(craft.towX, craft.towY)
            // The seams cut the silhouette, not the sky behind it.
            compositingStrategy = CompositingStrategy.Offscreen
          }
          .drawBehind { drawCraft(craft, flight()) },
      )
    },
    modifier = modifier,
  ) { (banner, line, art), constraints ->
    val loose = constraints.copy(minWidth = 0, minHeight = 0)
    val b = banner.measure(loose)
    val a = art.measure(Constraints.fixed(craft.width.dp.roundToPx(), craft.height.dp.roundToPx()))
    // On to the tow point, under the craft.
    val ropeLength = 10.dp.roundToPx() + (craft.towX * a.width).roundToInt()
    val r = line.measure(Constraints.fixed(ropeLength, 1.dp.roundToPx()))
    val tow = (craft.towY * a.height).roundToInt()
    // The rope's line: the banner's middle and the craft's tow point.
    val lineY = max(b.height / 2, tow)
    val artX = b.width + ropeLength - (craft.towX * a.width).roundToInt()
    layout(artX + a.width, max(lineY - b.height / 2 + b.height, lineY - tow + a.height)) {
      b.place(0, lineY - b.height / 2)
      r.place(b.width, lineY)
      a.place(artX, lineY - tow)
    }
  }
}

// The gaps between panels, in units: about the fleet's.
private const val GAP = 2.4f
private const val TWO_PI = 2 * PI.toFloat()
private const val HALF_PI = PI.toFloat() / 2

/** The craft in its box, 100 units wide: the silhouette, then what moves on it. */
private fun DrawScope.drawCraft(craft: SkyCraft, t: Float) {
  val s = size.width / 100
  val art = CRAFT_ART.getValue(craft)
  scale(s, s, pivot = Offset.Zero) {
    val body = Brush.verticalGradient(craft.colors, startY = 0f, endY = craft.unitHeight)
    art.parts.forEach { drawPath(it, body) }
    drawPath(art.seams, Color.Black, style = Stroke(GAP), blendMode = BlendMode.Clear)
    art.holes.forEach { drawPath(it, Color.Black, blendMode = BlendMode.Clear) }
    when (craft) {
      // A blade seen edge-on as it turns: tall, then thin.
      SkyCraft.Plane -> scale(1f, max(0.15f, abs(cos(t * TWO_PI * 4))), pivot = Offset(97f, 21f)) {
        drawOval(craft.colors[0].copy(alpha = 0.6f), Offset(95f, 4f), Size(4f, 34f))
      }
      // One flame for each engine, above and below the rope.
      SkyCraft.Rocket -> scale(0.8f + 0.12f * sin(t * TWO_PI * 6) + 0.08f * sin(t * TWO_PI * 11), 1f, pivot = Offset(21f, 20f)) {
        drawPath(ROCKET_FLAMES, Brush.horizontalGradient(listOf(FleetSunset[1], FleetGold[1]), startX = 0f, endX = 100f))
      }
      else -> {}
    }
  }
}

private class CraftArt(val parts: List<Path>, val seams: Path, val holes: List<Path>)

// Built once: the paths never change, only how they're drawn.
private val CRAFT_ART = SkyCraft.entries.associateWith(::craftArt)

private val ROCKET_FLAMES = Path().apply {
  for (y in listOf(14f, 26f)) {
    moveTo(21f, y - 2.6f)
    quadraticTo(8f, y - 3.2f, 3f, y)
    quadraticTo(8f, y + 3.2f, 21f, y + 2.6f)
    close()
  }
}

private fun craftArt(craft: SkyCraft): CraftArt = when (craft) {
  SkyCraft.Blimp -> {
    val envelope = oval(14f, 3f, 84f, 27f)
    val seams = oval(14f, 3f, 84f, 27f)
    for (x in listOf(38f, 58f, 78f)) {
      seams.moveTo(x, 1f)
      seams.quadraticTo(x + 7, 16.5f, x, 32f)
    }
    seams.moveTo(14f, 16.5f)
    seams.lineTo(98f, 16.5f)
    CraftArt(
      listOf(
        envelope,
        polygon(0f, 1f, 10f, 1f, 30f, 10f, 20f, 15f),
        polygon(0f, 32f, 10f, 32f, 30f, 23f, 20f, 18f),
        roundRect(46f, 31f, 22f, 8f, 3f),
      ),
      seams,
      listOf(51f, 57f, 63f).map { oval(it - 1.4f, 33.6f, 2.8f, 2.8f) },
    )
  }
  SkyCraft.Plane -> {
    val fuselage = Path().apply {
      moveTo(16f, 15f)
      lineTo(78f, 13f)
      quadraticTo(92f, 13f, 92f, 21f)
      quadraticTo(92f, 29f, 78f, 29f)
      lineTo(34f, 28f)
      lineTo(16f, 20f)
      close()
    }
    // A biplane: the lower wing along the fuselage's belly, the upper on struts.
    val seams = roundRect(38f, 25f, 34f, 5f, 2.5f).apply {
      moveTo(36f, 10f)
      lineTo(36f, 30f)
      moveTo(82f, 10f)
      quadraticTo(85f, 21f, 82f, 32f)
    }
    CraftArt(
      listOf(
        fuselage,
        roundRect(38f, 25f, 34f, 5f, 2.5f),
        roundRect(40f, 3f, 32f, 5f, 2.5f),
        rect(46f, 7f, 2.2f, 8f),
        rect(63f, 7f, 2.2f, 8f),
        polygon(8f, 2f, 17f, 2f, 32f, 15f, 16f, 16f),
        rect(54.8f, 29f, 2.4f, 5f),
        oval(51.5f, 33f, 9f, 9f),
      ),
      seams,
      listOf(roundRect(68f, 15.5f, 9f, 5f, 2f)),
    )
  }
  SkyCraft.Rocket -> {
    val body = Path().apply {
      moveTo(28f, 10f)
      lineTo(70f, 10f)
      quadraticTo(94f, 10f, 100f, 20f)
      quadraticTo(94f, 30f, 70f, 30f)
      lineTo(28f, 30f)
      close()
    }
    val seams = oval(56.5f, 14.5f, 11f, 11f).apply {
      moveTo(77f, 6f)
      quadraticTo(82f, 20f, 77f, 34f)
      moveTo(44f, 9f)
      lineTo(44f, 31f)
      moveTo(28f, 11f)
      lineTo(28f, 29f)
    }
    CraftArt(
      listOf(
        body,
        polygon(20f, 10f, 40f, 10f, 30f, 0f, 18f, 0f),
        polygon(20f, 30f, 40f, 30f, 30f, 40f, 18f, 40f),
        // Two engines, the rope tied on between them.
        polygon(21f, 11.5f, 28f, 11f, 28f, 17f, 21f, 16.5f),
        polygon(21f, 23.5f, 28f, 23f, 28f, 29f, 21f, 28.5f),
      ),
      seams,
      emptyList(),
    )
  }
  SkyCraft.Saucer -> CraftArt(
    listOf(
      oval(2f, 16f, 96f, 16f),
      Path.combine(PathOperation.Intersect, oval(32f, 2f, 36f, 32f), rect(0f, 0f, 100f, 20f)),
      Path.combine(PathOperation.Intersect, oval(34f, 26f, 32f, 14f), rect(0f, 30f, 100f, 16f)),
    ),
    oval(2f, 16f, 96f, 16f),
    listOf(18f, 34f, 50f, 66f, 82f).map { oval(it - 2.4f, 21.6f, 4.8f, 4.8f) },
  )
}

private fun polygon(vararg xy: Float) = Path().apply {
  moveTo(xy[0], xy[1])
  for (i in 2 until xy.size step 2) lineTo(xy[i], xy[i + 1])
  close()
}

private fun oval(x: Float, y: Float, w: Float, h: Float) = Path().apply { addOval(Rect(x, y, x + w, y + h)) }

private fun rect(x: Float, y: Float, w: Float, h: Float) = Path().apply { addRect(Rect(x, y, x + w, y + h)) }

private fun roundRect(x: Float, y: Float, w: Float, h: Float, r: Float) =
  Path().apply { addRoundRect(RoundRect(x, y, x + w, y + h, CornerRadius(r))) }
