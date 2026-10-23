package games.paperballoon.controller.ui.main

import android.os.Build
import android.view.animation.AccelerateInterpolator
import android.window.SplashScreenView
import androidx.annotation.RequiresApi

private const val LIFT_MS = 300L
private const val LIFT_DP = 40

/** The Android 12+ splash's exit: the balloon floats up as the sky fades to the home screen. */
@RequiresApi(Build.VERSION_CODES.S)
internal fun liftOff(splash: SplashScreenView) {
  splash.iconView?.animate()
    ?.translationY(-LIFT_DP * splash.resources.displayMetrics.density)
    ?.setInterpolator(AccelerateInterpolator())
    ?.setDuration(LIFT_MS)
  splash.animate().alpha(0f).setDuration(LIFT_MS).withEndAction(splash::remove)
}
