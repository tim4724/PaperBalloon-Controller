package games.paperballoon.controller.ui.main

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.AnimationVector1D
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import games.paperballoon.controller.R
import games.paperballoon.controller.data.BASE58
import games.paperballoon.controller.data.ROOM_CODE_LENGTH
import games.paperballoon.controller.data.originlessCode
import games.paperballoon.controller.data.validRoomCode
import games.paperballoon.controller.ui.components.KeyboardSheet
import kotlinx.coroutines.launch

/**
 * Typing a room code: one box per character of the suite's code (six, case-sensitive
 * Base58), drawn over one invisible field, so the keyboard, paste and delete stay the
 * system's own. A character pops into its box; one a code can't hold (0, O, I, l or
 * anything else outside Base58) nudges the row instead. The sixth submits by itself,
 * and a code the relay can't place ([error]) shakes the row and empties it, with the
 * reason under it.
 * A pasted launcher link gives up its code. While [loading] the field keeps its focus,
 * and the keyboard, but takes no edits. iOS: CodeSheet.swift.
 *
 * [KeyboardSheet], like the name sheet: see there for why.
 */
@Composable
fun CodeSheet(
  loading: Boolean,
  error: String?,
  /** The player changed the code after an error, which no longer applies. */
  onEdit: () -> Unit,
  onSubmit: (String) -> Unit,
  onDismiss: () -> Unit,
) {
  var code by remember { mutableStateOf("") }
  var focused by remember { mutableStateOf(false) }
  val shake = remember { Animatable(0f) }
  val scope = rememberCoroutineScope()
  val density = LocalDensity.current
  fun nudge(width: Dp) {
    scope.launch { shake.shake(with(density) { width.toPx() }) }
  }
  LaunchedEffect(error) {
    if (error == null) return@LaunchedEffect
    // A fresh start rather than hunting for the wrong character.
    code = ""
    shake.shake(with(density) { 12.dp.toPx() })
  }

  // Keeps the field to what a code can be: characters outside Base58 and past the sixth
  // are dropped, with a nudge. An insertion that is a whole code or a launcher link (a
  // paste) replaces the field instead, without one.
  fun accept(new: String) {
    if (loading) return
    val old = code
    val inserted = if (new.startsWith(old)) new.drop(old.length) else new
    val pasted = if (inserted.length > 1) originlessCode(inserted)?.takeIf(::validRoomCode) else null
    val next = pasted ?: new.filter { it in BASE58 }.take(ROOM_CODE_LENGTH)
    if (pasted == null && next.length < new.length) nudge(5.dp)
    if (next == old) return
    code = next
    if (error != null) onEdit()
    if (next.length == ROOM_CODE_LENGTH && old.length < ROOM_CODE_LENGTH) onSubmit(next)
  }

  KeyboardSheet(fullHeight = false, color = null, onClosed = onDismiss) {
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { focus.requestFocus() }
    Column(
      Modifier.fillMaxWidth().padding(start = 20.dp, end = 20.dp, top = 24.dp, bottom = 28.dp),
      verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
      Text(stringResource(R.string.enter_room_code), style = MaterialTheme.typography.titleLarge)
      val label = stringResource(R.string.room_code)
      BasicTextField(
        // The caret always at the end: the boxes fill left to right.
        value = TextFieldValue(code, TextRange(code.length)),
        onValueChange = { accept(it.text) },
        singleLine = true,
        // A Base58 code is not a word: the password layout keeps suggestions, correction
        // and the keyboard's learning out of it (the boxes show it in the clear).
        keyboardOptions = KeyboardOptions(
          keyboardType = KeyboardType.Password,
          capitalization = KeyboardCapitalization.None,
          autoCorrectEnabled = false,
          imeAction = ImeAction.Done,
        ),
        textStyle = TextStyle(color = Color.Transparent),
        cursorBrush = SolidColor(Color.Transparent),
        modifier = Modifier
          .fillMaxWidth()
          .focusRequester(focus)
          .onFocusChanged { focused = it.isFocused }
          .graphicsLayer { translationX = shake.value }
          .semantics { contentDescription = label },
        decorationBox = { field ->
          Box {
            CodeBoxes(code, active = focused && !loading, failed = error != null)
            // The real field, drawn clear: it takes the input, the boxes show it.
            Box(Modifier.alpha(0f)) { field() }
          }
        },
      )
      // The hint keeps its room under whatever stands in for it, so the sheet never
      // changes height.
      Box {
        val style = MaterialTheme.typography.bodyMedium
        val color = MaterialTheme.colorScheme.onSurfaceVariant
        Text(
          stringResource(R.string.code_hint),
          style = style,
          color = color,
          modifier = Modifier.alpha(if (loading || error != null) 0f else 1f),
        )
        if (loading) {
          Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp)
            Text(stringResource(R.string.joining), style = style, color = color)
          }
        } else if (error != null) {
          Text(error, style = style, color = MaterialTheme.colorScheme.error)
        }
      }
    }
  }
}

@Composable
private fun CodeBoxes(code: String, active: Boolean, failed: Boolean) {
  Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
    repeat(ROOM_CODE_LENGTH) { i ->
      CodeBox(code.getOrNull(i), active = active && i == code.length, failed = failed, Modifier.weight(1f))
    }
  }
}

// One character's box: it pops in when typed; the next box to fill carries a blinking
// caret.
@Composable
private fun CodeBox(character: Char?, active: Boolean, failed: Boolean, modifier: Modifier) {
  val scheme = MaterialTheme.colorScheme
  val shape = RoundedCornerShape(12.dp)
  val border by animateColorAsState(
    when {
      failed -> scheme.error
      active -> scheme.primary
      else -> Color.Transparent
    },
    tween(150),
    label = "codeBoxBorder",
  )
  Box(
    modifier.height(58.dp).background(scheme.surfaceContainerHighest, shape).border(2.dp, border, shape),
    contentAlignment = Alignment.Center,
  ) {
    if (character != null) {
      // Keyed on the character, so a new one pops in from small.
      val pop = remember(character) { Animatable(0.4f) }
      LaunchedEffect(pop) { pop.animateTo(1f, spring(dampingRatio = 0.55f, stiffness = Spring.StiffnessMediumLow)) }
      Text(
        character.toString(),
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.SemiBold,
        fontSize = 28.sp,
        modifier = Modifier.graphicsLayer {
          scaleX = pop.value
          scaleY = pop.value
          alpha = ((pop.value - 0.4f) / 0.6f).coerceIn(0f, 1f)
        },
      )
    } else if (active) {
      Caret()
    }
  }
}

@Composable
private fun Caret() {
  val alpha by rememberInfiniteTransition(label = "caret").animateFloat(
    initialValue = 1f,
    targetValue = 0f,
    animationSpec = infiniteRepeatable(tween(450), RepeatMode.Reverse),
    label = "caretAlpha",
  )
  Box(Modifier.width(2.dp).height(26.dp).alpha(alpha).background(MaterialTheme.colorScheme.primary, RoundedCornerShape(1.dp)))
}

// A quick side-to-side that settles back.
private suspend fun Animatable<Float, AnimationVector1D>.shake(widthPx: Float) {
  for ((i, x) in listOf(-1f, 1f, -0.8f, 0.8f, -0.4f, 0f).withIndex()) {
    animateTo(x * widthPx, tween(if (i == 0) 50 else 70))
  }
}
