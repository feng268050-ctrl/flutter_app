package com.lasercyber.lws.frostui.dialog

import com.lasercyber.lws.frostui.blur.FrostBackdropDisplayMode

/** Determines when an overlay dialog is allowed to capture its first backdrop frame. */
enum class FrostBackdropCapturePolicy {
    AUTO_AFTER_LAYOUT,
    AFTER_IME_STABLE,
    MANUAL,
}

/** Lifecycle of the backdrop frame owned by one Activity overlay session. */
internal enum class FrostBackdropCaptureState {
    IDLE,
    CAPTURING_INITIAL,
    READY,
    CAPTURING_REPLACEMENT,
}

/** Identifies why a capture was requested so logs and stale results can be correlated. */
internal enum class FrostBackdropCaptureReason(val logValue: String) {
    INITIAL("initial"),
    RETRY("retry"),
    MANUAL("manual"),
    RECAPTURE("recapture"),
    BOUNDS_CHANGED("bounds"),
    IME_STABLE("ime"),
    KEYBOARD_HIDDEN("keyboard-hidden"),
}

internal enum class FrostBackdropCaptureExecution {
    SYNC,
    ASYNC,
}

internal enum class FrostInitialCaptureDecision {
    WAIT_FOR_LAYOUT,
    CAPTURE_LOCAL,
    CAPTURE_FULLSCREEN_FALLBACK,
}

internal data class FrostBackdropCaptureRequest(
    val reason: FrostBackdropCaptureReason,
    val mode: FrostBackdropDisplayMode,
    val execution: FrostBackdropCaptureExecution,
    val surface: FrostBackdropSurface = FrostBackdropSurface.DIALOG_CARD,
    val forceReapply: Boolean = false,
    val applyToOverlays: Boolean = true,
    val overscanPx: Int = 0,
    /** When false, page FrostCardViews stay visible (IME keyboard / frozen-page dialog crop). */
    val hidePageFrostCardsDuringCapture: Boolean = true,
)

/** Geometry and display contract captured together with the current frozen backdrop bitmap. */
data class FrostBackdropFrameMetadata(
    val mode: FrostBackdropDisplayMode,
    val anchor: FrozenDialogAnchor?,
    val scaleFactor: Float,
    val overscanPx: Int,
    val generation: Int,
)

internal object FrostBackdropCaptureStateMachine {

    fun onRequest(hasFrame: Boolean): FrostBackdropCaptureState =
        if (hasFrame) {
            FrostBackdropCaptureState.CAPTURING_REPLACEMENT
        } else {
            FrostBackdropCaptureState.CAPTURING_INITIAL
        }

    fun onComplete(success: Boolean, hasFrame: Boolean): FrostBackdropCaptureState =
        if (success || hasFrame) {
            FrostBackdropCaptureState.READY
        } else {
            FrostBackdropCaptureState.IDLE
        }
}

internal fun resolveInitialFrostBackdropCaptureDecision(
    cardReady: Boolean,
    attempts: Int,
    maxAttempts: Int,
): FrostInitialCaptureDecision = when {
    attempts >= maxAttempts -> FrostInitialCaptureDecision.CAPTURE_FULLSCREEN_FALLBACK
    cardReady -> FrostInitialCaptureDecision.CAPTURE_LOCAL
    else -> FrostInitialCaptureDecision.WAIT_FOR_LAYOUT
}

internal fun resolveFrostBackdropCapturePolicy(
    deferUntilIme: Boolean,
    deferUntilManualCapture: Boolean,
): FrostBackdropCapturePolicy = when {
    deferUntilManualCapture -> FrostBackdropCapturePolicy.MANUAL
    deferUntilIme -> FrostBackdropCapturePolicy.AFTER_IME_STABLE
    else -> FrostBackdropCapturePolicy.AUTO_AFTER_LAYOUT
}
