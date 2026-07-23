package com.lasercyber.lws.frostui.dialog

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.graphics.Bitmap
import android.graphics.Rect
import android.os.Build
import android.os.SystemClock
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.ViewParent
import android.view.ViewTreeObserver
import android.view.animation.AccelerateInterpolator
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.LinearLayout
import com.blankj.utilcode.util.ActivityUtils
import com.lasercyber.lws.frostui.border.FrostBlurIntensity
import com.lasercyber.lws.frostui.border.FrostDimens
import com.lasercyber.lws.frostui.border.FrostTone
import com.lasercyber.lws.frostui.blur.FrostBackdropCapture
import com.lasercyber.lws.frostui.blur.FrostBackdropDisplayMode
import com.lasercyber.lws.frostui.blur.FrostBackdropResolver
import com.lasercyber.lws.frostui.blur.FrostCaptureTarget
import com.lasercyber.lws.frostui.card.FrostCardBlurRegistry
import com.lasercyber.lws.frostui.card.interop.FrostCardView
import com.lasercyber.lws.ime.interop.ImeKeyboardBackdropHost
import com.lasercyber.lws.ime.interop.ImeKeyboardOverlay
import com.lasercyber.lws.ime.interop.ImeOverlayHost
import java.lang.ref.WeakReference
import java.util.WeakHashMap
import java.util.concurrent.Future
import kotlin.math.roundToInt

/** Per-activity in-window overlay lifecycle for frost prompt dialogs. */
object FrostOverlayHost {

    private const val TAG = "FrostBackdrop"

    private const val CARD_WIDTH_FRACTION = 0.62f

    /** Frames to wait after overlay reveal before freezing backdrop (matches legacy BlurView triple-invalidate). */
    private const val BACKDROP_CAPTURE_FRAME_WAIT = 5
    /** Debounce before re-sampling dialog + keyboard backdrops after layout settles. */
    private const val OVERLAY_BACKDROP_RECAPTURE_DEBOUNCE_MS = 80L
    private const val INITIAL_LOCAL_CAPTURE_MAX_ATTEMPTS = 30

    /** Resolved card bounds for [attachOverlay]. */
    class CardWidth private constructor(
        private val widthPx: Int?,
        private val widthFraction: Float?,
        private val heightPx: Int?,
        private val contentInsetPx: Int,
        private val expandBodyScroll: Boolean,
        private val minHeightPx: Int,
        private val maxHeightPx: Int,
    ) {
        fun withMaxHeight(maxHeightPx: Int, expandBodyScrollWhenCapped: Boolean): CardWidth =
            CardWidth(
                widthPx = widthPx,
                widthFraction = widthFraction,
                heightPx = heightPx,
                contentInsetPx = contentInsetPx,
                expandBodyScroll = expandBodyScrollWhenCapped || expandBodyScroll,
                minHeightPx = minHeightPx,
                maxHeightPx = maxHeightPx,
            )

        fun getMaxHeightPx(): Int = maxHeightPx

        fun getMinHeightPx(): Int = minHeightPx

        fun shouldExpandBodyScroll(): Boolean = expandBodyScroll

        fun getContentInsetPx(): Int = contentInsetPx

        fun hasFixedHeight(): Boolean =
            contentInsetPx > 0 || (heightPx != null && heightPx > 0)

        fun resolvePx(activity: Activity): Int {
            val screenWidth = activity.resources.displayMetrics.widthPixels
            if (contentInsetPx > 0) {
                return screenWidth - contentInsetPx * 2
            }
            if (widthPx != null && widthPx > 0) {
                return widthPx
            }
            if (widthFraction != null && widthFraction > 0f) {
                return (screenWidth * widthFraction).roundToInt()
            }
            return (screenWidth * CARD_WIDTH_FRACTION).roundToInt()
        }

        fun resolveHeightPx(activity: Activity): Int {
            if (contentInsetPx > 0) {
                return maxOf(0, resolveAvailableHeightPx(activity) - contentInsetPx * 2)
            }
            if (heightPx != null && heightPx > 0) {
                return heightPx
            }
            return ViewGroup.LayoutParams.WRAP_CONTENT
        }

        companion object {
            @JvmStatic
            fun defaults(): CardWidth = defaults(false)

            @JvmStatic
            fun defaults(expandBodyScroll: Boolean): CardWidth =
                CardWidth(null, null, null, 0, expandBodyScroll, 0, 0)

            @JvmStatic
            fun px(widthPx: Int): CardWidth = px(widthPx, null)

            @JvmStatic
            fun px(widthPx: Int, heightPx: Int?): CardWidth =
                px(widthPx, heightPx, heightPx != null, 0)

            @JvmStatic
            fun px(
                widthPx: Int,
                heightPx: Int?,
                expandBodyScroll: Boolean,
                minHeightPx: Int,
            ): CardWidth = CardWidth(widthPx, null, heightPx, 0, expandBodyScroll, minHeightPx, 0)

            @JvmStatic
            fun fraction(widthFraction: Float): CardWidth = fraction(widthFraction, null)

            @JvmStatic
            fun fraction(widthFraction: Float, heightPx: Int?): CardWidth =
                CardWidth(null, widthFraction, heightPx, 0, heightPx != null, 0, 0)

            @JvmStatic
            fun inset(contentInsetPx: Int): CardWidth =
                CardWidth(null, null, null, contentInsetPx, true, 0, 0)

            private fun resolveAvailableHeightPx(activity: Activity): Int {
                val contentRoot = activity.findViewById<View>(android.R.id.content)
                if (contentRoot != null && contentRoot.height > 0) {
                    return contentRoot.height
                }
                val metrics = activity.resources.displayMetrics
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    val bounds: Rect = activity.windowManager.currentWindowMetrics.bounds
                    return bounds.height()
                }
                return metrics.heightPixels
            }
        }
    }

    private class ActivitySession(val activity: Activity) {
        var frozenBackdrop: Bitmap? = null
        var frozenDialogAnchor: FrozenDialogAnchor? = null
        var frozenBackdropMetadata: FrostBackdropFrameMetadata? = null
        var frozenBackdropGeneration: Int = 0
        /** Full-window blur retained for dialog/keyboard IME crops only — never applied to page cards. */
        var pageFrozenBackdrop: Bitmap? = null
        var pageFrozenBackdropGeneration: Int = 0
        var deferFrozenBackdropUntilIme: Boolean = false
        var deferFrozenBackdropUntilManualCapture: Boolean = false
        /** IME input dialogs: freeze full-window blur once, then recrop when the card lifts. */
        var preferFullscreenDialogCapture: Boolean = false
        /** Blocks BOUNDS_CHANGED recapture while the IME lifts the card (until IME_STABLE apply). */
        var awaitingImeBackdropCapture: Boolean = false
        var capturePolicy: FrostBackdropCapturePolicy =
            FrostBackdropCapturePolicy.AUTO_AFTER_LAYOUT
        var captureState: FrostBackdropCaptureState = FrostBackdropCaptureState.IDLE
        var overlayCount: Int = 0
        var backdropCaptureGeneration: Int = 0
        var backdropBlurFuture: Future<*>? = null
        var backdropPreDrawRoot: WeakReference<ViewGroup>? = null
        var backdropPreDrawListener: ViewTreeObserver.OnPreDrawListener? = null
        var keyboardFrozenBackdrop: Bitmap? = null
        var keyboardFrozenAnchor: FrozenDialogAnchor? = null
        var keyboardFrozenBackdropMetadata: FrostBackdropFrameMetadata? = null
        var keyboardFrozenBackdropGeneration: Int = 0
        var keyboardBackdropBlurFuture: Future<*>? = null
        var keyboardBackdropCaptureGeneration: Int = 0
        var pendingOverlayRecaptureRunnable: Runnable? = null
        /** True after dialog + keyboard backdrops were captured for the current IME session. */
        var imeBackdropCaptureComplete: Boolean = false
        val overlays: MutableList<WeakReference<View>> = ArrayList()
    }

    private val sessions: MutableMap<Activity, ActivitySession> = WeakHashMap()

    private fun dismissCallbackTag(context: Context): Int =
        FrostResourceIds.viewId(context, "frost_dialog_dismiss_notified")

    private fun dismissingTag(context: Context): Int =
        FrostResourceIds.viewId(context, "frost_dialog_dismissing")

    private fun dismissFinishedTag(context: Context): Int =
        FrostResourceIds.viewId(context, "frost_dialog_dismiss_finished")

    private fun onDismissTag(context: Context): Int =
        FrostResourceIds.viewId(context, "frost_dialog_on_dismiss")

    private fun dismissOnScrimClickTag(context: Context): Int =
        FrostResourceIds.viewId(context, "frost_dialog_dismiss_on_scrim_click")

    private fun frostedGlassRootId(context: Context): Int =
        FrostResourceIds.viewId(context, "frost_dialog_root")

    @JvmStatic
    fun hasOverlays(activity: Activity): Boolean {
        val session = sessions[activity] ?: return false
        return session.overlayCount > 0 && hasAttachedOverlay(session)
    }

    @JvmStatic
    fun getFrozenBackdrop(activity: Activity): Bitmap? = sessions[activity]?.frozenBackdrop

    @JvmStatic
    fun getPageFrozenBackdrop(activity: Activity): Bitmap? = sessions[activity]?.pageFrozenBackdrop

    @JvmStatic
    fun getFrozenDialogAnchor(activity: Activity): FrozenDialogAnchor? =
        sessions[activity]?.frozenDialogAnchor

    @JvmStatic
    fun getFrozenBackdropGeneration(activity: Activity): Int =
        sessions[activity]?.frozenBackdropGeneration ?: 0

    @JvmStatic
    fun getPageFrozenBackdropGeneration(activity: Activity): Int =
        sessions[activity]?.pageFrozenBackdropGeneration ?: 0

    @JvmStatic
    fun getFrozenBackdropFrameMetadata(activity: Activity): FrostBackdropFrameMetadata? =
        sessions[activity]?.frozenBackdropMetadata

    @JvmStatic
    fun getKeyboardFrozenBackdrop(activity: Activity): Bitmap? =
        sessions[activity]?.keyboardFrozenBackdrop

    @JvmStatic
    fun getKeyboardFrozenBackdropGeneration(activity: Activity): Int =
        sessions[activity]?.keyboardFrozenBackdropGeneration ?: 0

    @JvmStatic
    fun hasKeyboardFrozenBackdrop(activity: Activity): Boolean =
        sessions[activity]?.keyboardFrozenBackdrop?.takeIf { !it.isRecycled } != null

    @JvmStatic
    fun shouldKeepDialogBackdropLocked(activity: Activity): Boolean {
        val session = sessions[activity] ?: return false
        return session.capturePolicy == FrostBackdropCapturePolicy.AUTO_AFTER_LAYOUT &&
            session.frozenBackdropMetadata?.mode == FrostBackdropDisplayMode.FULLSCREEN
    }

    /**
     * Captures dialog + keyboard backdrops once per IME session (after card lift settles).
     * Subsequent calls are no-ops until [notifyKeyboardHidden].
     */
    @JvmStatic
    fun captureImeBackdropOnce(activity: Activity): Boolean {
        val session = sessions[activity] ?: return false
        if (session.overlayCount == 0 || !isKeyboardVisible(session)) {
            return false
        }
        if (session.imeBackdropCaptureComplete) {
            Log.d(TAG, "captureImeBackdropOnce skipped; already captured this IME session")
            return false
        }
        if (session.pageFrozenBackdrop?.isRecycled != false) {
            Log.w(TAG, "captureImeBackdropOnce aborted; pageFrozenBackdrop missing")
            return false
        }
        val contentRoot = activity.findViewById<ViewGroup>(android.R.id.content) ?: return false
        session.deferFrozenBackdropUntilIme = false
        session.capturePolicy = FrostBackdropCapturePolicy.AUTO_AFTER_LAYOUT

        var dialogApplied = session.frozenBackdrop?.isRecycled == false
        val card = findDialogCard(session)
        if (card != null && card.width > 0 && card.height > 0) {
            val anchor = resolveAnchorForView(contentRoot, card)
            if (anchor != null &&
                applyDialogBackdropCropFromPageSnapshot(session, anchor, forceReapply = false)
            ) {
                dialogApplied = true
            }
        }

        var keyboardApplied = applyKeyboardBackdropFromSessionSnapshot(
            session,
            contentRoot,
            forceReapply = false,
        )
        if (!keyboardApplied) {
            keyboardApplied = requestFrozenBackdropCapture(
                session,
                contentRoot,
                FrostBackdropCaptureRequest(
                    reason = FrostBackdropCaptureReason.IME_STABLE,
                    mode = FrostBackdropDisplayMode.LOCAL,
                    execution = FrostBackdropCaptureExecution.ASYNC,
                    surface = FrostBackdropSurface.IME_KEYBOARD,
                    forceReapply = false,
                    hidePageFrostCardsDuringCapture = false,
                ),
            )
        }

        if (dialogApplied && isKeyboardBackdropReady(session)) {
            session.imeBackdropCaptureComplete = true
            session.awaitingImeBackdropCapture = false
            Log.d(TAG, "captureImeBackdropOnce complete dialog=$dialogApplied keyboard=$keyboardApplied")
            return true
        }
        if (isKeyboardVisible(session)) {
            scheduleKeyboardBackdropRecapture(
                session,
                contentRoot,
                FrostBackdropCaptureReason.IME_STABLE,
            )
        }
        Log.d(TAG, "captureImeBackdropOnce pending dialog=$dialogApplied keyboard=$keyboardApplied")
        return dialogApplied || keyboardApplied
    }

    /**
     * @deprecated Use [captureImeBackdropOnce]; kept for callers that still invoke this name.
     */
    @JvmStatic
    fun refreshFrozenBackdropAfterIme(activity: Activity): Boolean {
        return captureImeBackdropOnce(activity)
    }

    /**
     * Keyboard backdrop is captured together with the dialog in [captureImeBackdropOnce].
     */
    @JvmStatic
    fun refreshKeyboardFrozenBackdrop(activity: Activity): Boolean {
        val session = sessions[activity] ?: return false
        if (session.imeBackdropCaptureComplete) {
            return false
        }
        return captureImeBackdropOnce(activity)
    }

    /** Clears the keyboard frosted-glass frame when the custom IME panel is dismissed. */
    @JvmStatic
    fun notifyKeyboardHidden(activity: Activity) {
        val session = sessions[activity] ?: return
        releaseKeyboardFrozenBackdrop(session)
    }

    /**
     * Captures a card-sized LOCAL frozen backdrop at the current dialog card bounds.
     * Boot self-check calls this after the footer is shown so blur matches the final card size.
     */
    @JvmStatic
    fun captureFrozenBackdropAtAnchor(activity: Activity): Boolean {
        val session = sessions[activity] ?: return false
        if (session.overlayCount == 0) {
            return false
        }
        val contentRoot = activity.findViewById<ViewGroup>(android.R.id.content) ?: return false
        val accepted = requestFrozenBackdropCapture(
            session,
            contentRoot,
            FrostBackdropCaptureRequest(
                reason = FrostBackdropCaptureReason.MANUAL,
                mode = FrostBackdropDisplayMode.LOCAL,
                execution = FrostBackdropCaptureExecution.ASYNC,
                surface = FrostBackdropSurface.DIALOG_CARD,
                forceReapply = true,
            ),
        )
        if (accepted) {
            session.deferFrozenBackdropUntilManualCapture = false
            session.capturePolicy = FrostBackdropCapturePolicy.AUTO_AFTER_LAYOUT
        }
        return accepted
    }

    /**
     * Re-captures the dialog backdrop at the current card anchor (preferred) or schedules a retry.
     */
    @JvmStatic
    fun recaptureFrozenBackdrop(activity: Activity) {
        val session = sessions[activity] ?: return
        if (session.overlayCount == 0) {
            return
        }
        val contentRoot = activity.findViewById<ViewGroup>(android.R.id.content) ?: return
        if (session.frozenDialogAnchor != null &&
            requestFrozenBackdropCapture(
                session,
                contentRoot,
                FrostBackdropCaptureRequest(
                    reason = FrostBackdropCaptureReason.RECAPTURE,
                    mode = FrostBackdropDisplayMode.LOCAL,
                    execution = FrostBackdropCaptureExecution.SYNC,
                    forceReapply = true,
                ),
            )
        ) {
            return
        }
        if (requestFrozenBackdropCapture(
                session,
                contentRoot,
                FrostBackdropCaptureRequest(
                    reason = FrostBackdropCaptureReason.RECAPTURE,
                    mode = FrostBackdropDisplayMode.FULLSCREEN,
                    execution = FrostBackdropCaptureExecution.SYNC,
                    forceReapply = true,
                ),
            )
        ) {
            return
        }
        FrostBackdropSnapshot.recycle(session.frozenBackdrop)
        session.frozenBackdrop = null
        session.frozenDialogAnchor = null
        session.frozenBackdropMetadata = null
        session.captureState = FrostBackdropCaptureState.IDLE
        scheduleFrozenBackdropCapture(session, contentRoot)
    }

    /**
     * Called when a dialog card's bounds change after the frozen backdrop was applied.
     * LOCAL captures re-sample at the new anchor; fullscreen boot frames stay matrix-aligned.
     */
    @JvmStatic
    fun notifyDialogCardBoundsChanged(activity: Activity) {
        val session = sessions[activity] ?: return
        if (session.overlayCount == 0 || session.frozenBackdrop == null) {
            return
        }
        if (session.deferFrozenBackdropUntilIme || session.deferFrozenBackdropUntilManualCapture) {
            return
        }
        if (session.awaitingImeBackdropCapture || session.imeBackdropCaptureComplete) {
            Log.d(TAG, "skip bounds recapture; IME backdrop frozen or pending initial capture")
            return
        }
        if (isKeyboardVisible(session)) {
            return
        }
        if (session.frozenBackdropMetadata?.mode == FrostBackdropDisplayMode.FULLSCREEN) {
            realignFullscreenDialogBackdropOnBoundsChanged(session, activity)
            return
        }
        val contentRoot = activity.findViewById<ViewGroup>(android.R.id.content) ?: return
        scheduleOverlayBackdropRecapture(session, contentRoot, FrostBackdropCaptureReason.BOUNDS_CHANGED)
    }

    @JvmStatic
    fun isFrozenBackdropDeferred(activity: Activity): Boolean {
        val session = sessions[activity] ?: return false
        return session.deferFrozenBackdropUntilIme ||
            (session.deferFrozenBackdropUntilManualCapture && session.frozenBackdrop == null)
    }

    @JvmStatic
    fun hasAnyOverlay(): Boolean {
        for (session in sessions.values) {
            if (session.overlayCount > 0 && hasAttachedOverlay(session)) {
                return true
            }
        }
        return false
    }

    @JvmStatic
    fun dismissAllOnActivity(activity: Activity, except: View?) {
        val session = sessions[activity] ?: return
        val toRemove = ArrayList<View>()
        for (ref in session.overlays) {
            val overlay = ref.get()
            if (overlay != null && overlay !== except && overlay.parent is ViewGroup) {
                if (com.lasercyber.lws.ui.component.dialog.WarnDialogUtil.shouldProtectOverlay(overlay)) {
                    continue
                }
                toRemove.add(overlay)
            }
        }
        for (overlay in toRemove) {
            dismissImmediate(activity, overlay, null)
        }
    }

    @JvmStatic
    fun onActivityDestroyed(activity: Activity) {
        val session = sessions.remove(activity)
        if (session != null) {
            val overlays = session.overlays.mapNotNull { it.get() }.toList()
            for (overlay in overlays) {
                dismissImmediate(activity, overlay, null)
            }
            session.overlays.clear()
            releaseFrozenBackdrop(session)
            session.overlayCount = 0
        }
        val contentRoot = activity.findViewById<ViewGroup>(android.R.id.content) ?: return
        removeOrphanOverlays(contentRoot, activity)
        ensureBlurTargetRestored(contentRoot)
    }

    @JvmStatic
    @JvmOverloads
    fun attachOverlay(
        context: Context,
        overlay: View,
        dismissOnScrimClick: Boolean,
        onScrimDismiss: Runnable?,
        cardWidth: CardWidth,
        tone: FrostTone,
        deferFrozenBackdropUntilIme: Boolean = false,
        deferFrozenBackdropUntilManualCapture: Boolean = false,
        preferFullscreenDialogCapture: Boolean = false,
    ): Activity? {
        val activity = findActivity(context) ?: return null
        if (activity.isFinishing || activity.isDestroyed) {
            return null
        }

        val contentRoot = activity.findViewById<ViewGroup>(android.R.id.content) ?: return null

        val session = sessions.getOrPut(activity) { ActivitySession(activity) }
        if (session.overlayCount == 0) {
            ensureBlurTargetRestored(contentRoot)
            capturePageFrozenBackdropOnce(session, contentRoot, activity)
            session.deferFrozenBackdropUntilManualCapture = deferFrozenBackdropUntilManualCapture
            session.capturePolicy = resolveFrostBackdropCapturePolicy(
                deferUntilIme = deferFrozenBackdropUntilIme,
                deferUntilManualCapture = deferFrozenBackdropUntilManualCapture,
            )
            if (deferFrozenBackdropUntilManualCapture) {
                Log.d(TAG, "attachOverlay deferred capture until manual recapture")
            } else if (!deferFrozenBackdropUntilIme && session.frozenBackdrop == null) {
                promotePageFrozenToDialogFrozen(session)
            }
            if (preferFullscreenDialogCapture) {
                session.preferFullscreenDialogCapture = true
                Log.d(TAG, "attachOverlay prefer fullscreen initial dialog capture (IME input)")
            }
        }
        if (deferFrozenBackdropUntilIme) {
            session.deferFrozenBackdropUntilIme = true
            session.awaitingImeBackdropCapture = true
            session.capturePolicy = FrostBackdropCapturePolicy.AFTER_IME_STABLE
            invalidateBackdropCapture(session, "imeDeferred")
            if (session.frozenBackdrop != null) {
                FrostBackdropSnapshot.recycle(session.frozenBackdrop)
                session.frozenBackdrop = null
                session.frozenDialogAnchor = null
                session.frozenBackdropMetadata = null
                session.frozenBackdropGeneration++
                session.captureState = FrostBackdropCaptureState.IDLE
            }
            Log.d(TAG, "attachOverlay deferred capture until IME settles")
        }

        configureCardLayout(overlay, activity, cardWidth)
        overlay.setTag(dismissOnScrimClickTag(context), dismissOnScrimClick)

        val scrimId = FrostResourceIds.viewId(context, "frost_dialog_scrim")
        val cardId = FrostResourceIds.viewId(context, "frost_dialog_content")
        val scrim = overlay.findViewById<View>(scrimId)
        val card = overlay.findViewById<View>(cardId)
        if (scrim != null) {
            if (dismissOnScrimClick && onScrimDismiss != null) {
                scrim.setOnClickListener { onScrimDismiss.run() }
            } else {
                scrim.setOnClickListener(null)
                scrim.isClickable = true
                scrim.isFocusable = false
                scrim.isFocusableInTouchMode = false
            }
        }
        if (card != null) {
            card.isClickable = true
            card.isFocusable = false
        }

        contentRoot.addView(
            overlay,
            ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
        session.overlayCount++
        session.overlays.add(WeakReference(overlay))
        if (session.overlayCount == 1) {
            freezePageBackdropsDuringOverlay(session)
            FrostCardBlurRegistry.onOverlayAttached?.invoke(activity)
        }
        when {
            session.deferFrozenBackdropUntilIme -> {
                if (tone != FrostTone.LIGHT) {
                    playFadeIn(overlay) {
                        ImeOverlayHost.onInputDialogEnterAnimationEnd(activity, overlay)
                    }
                } else {
                    overlay.alpha = 1f
                    overlay.post {
                        ImeOverlayHost.onInputDialogEnterAnimationEnd(activity, overlay)
                    }
                }
            }
            session.deferFrozenBackdropUntilManualCapture -> {
                // Boot self-check captures once when the footer is shown at final card size.
                if (tone != FrostTone.LIGHT) {
                    playFadeIn(overlay)
                }
            }
            session.frozenBackdrop != null -> {
                applyFrozenBackdropToOverlays(session, forceReapply = true)
                overlay.post { applyFrozenBackdropToOverlays(session, forceReapply = true) }
            }
            else -> {
                // Ordinary prompts capture the laid-out card region asynchronously. A bounded
                // fullscreen fallback is used only if card bounds never become available.
                scheduleFrozenBackdropCapture(session, contentRoot)
                if (tone != FrostTone.LIGHT) {
                    playFadeIn(overlay)
                }
            }
        }
        maintainImmersiveSystemUi(activity)
        if (tone == FrostTone.LIGHT) {
            overlay.alpha = 1f
        }
        overlay.post { maintainImmersiveSystemUi(activity) }
        return activity
    }

    @JvmStatic
    fun dismiss() {
        for (session in ArrayList(sessions.values)) {
            val top = findTopOverlay(session) ?: continue
            dismiss(session.activity, top, null)
            return
        }
    }

    @JvmStatic
    fun dismiss(activity: Activity?) {
        if (activity == null) {
            dismiss()
            return
        }
        val session = sessions[activity]
        val top = session?.let { findTopOverlay(it) }
        if (top != null) {
            dismiss(activity, top, null)
        }
    }

    @JvmStatic
    fun dismissImmediate() {
        for (session in ArrayList(sessions.values)) {
            val top = findTopOverlay(session) ?: continue
            dismissImmediate(session.activity, top, null)
            return
        }
    }

    @JvmStatic
    fun dismissImmediate(activity: Activity?) {
        if (activity == null) {
            dismissImmediate()
            return
        }
        val session = sessions[activity]
        val top = session?.let { findTopOverlay(it) }
        if (top != null) {
            dismissImmediate(activity, top, null)
        }
    }

    @JvmStatic
    fun dismiss(activity: Activity?, overlayHint: View?, onDismiss: Runnable?) {
        val overlay = resolveOverlay(activity, overlayHint)
        if (overlay == null) {
            notifyDismiss(null, resolveOnDismiss(null, onDismiss))
            return
        }
        val host = activity ?: findActivity(overlay.context)
        if (host == null || host.isFinishing) {
            dismissImmediate(host, overlay, onDismiss)
            return
        }
        if (overlay.parent == null) {
            onOverlayDetached(host, overlay)
            notifyDismiss(overlay, resolveOnDismiss(overlay, onDismiss))
            return
        }
        // Dialog fade-out first; hide the keyboard after the overlay animation completes.
        val hasImeSession = ImeOverlayHost.hasImeSession(overlay)
        val dismissingId = dismissingTag(overlay.context)
        if (overlay.getTag(dismissingId) == true) {
            dismissImmediate(host, overlay, onDismiss)
            return
        }
        overlay.animate().cancel()
        overlay.setTag(dismissCallbackTag(overlay.context), null)
        overlay.setTag(dismissingId, true)
        val duration = FrostDimens.fadeOutDurationMs(overlay.context)
        val finish = Runnable {
            if (overlay.getTag(dismissFinishedTag(overlay.context)) == true) {
                return@Runnable
            }
            overlay.setTag(dismissFinishedTag(overlay.context), true)
            overlay.setTag(dismissingId, null)
            val removeOverlay = Runnable {
                if (overlay.parent != null) {
                    dismissImmediate(host, overlay, onDismiss)
                } else {
                    onOverlayDetached(host, overlay)
                    notifyDismiss(overlay, resolveOnDismiss(overlay, onDismiss))
                }
            }
            if (hasImeSession) {
                ImeOverlayHost.hideKeyboardAfterDialogExit(host, overlay, removeOverlay)
            } else {
                removeOverlay.run()
            }
        }
        overlay.animate()
            .alpha(0f)
            .setDuration(duration.toLong())
            .setInterpolator(AccelerateInterpolator())
            .withEndAction(finish)
            .start()
        overlay.postDelayed(finish, duration + 32L)
    }

    @JvmStatic
    fun dismissImmediate(activity: Activity?, overlayHint: View?, onDismiss: Runnable?) {
        val overlay = resolveOverlay(activity, overlayHint)
        val host = activity ?: overlay?.let { findActivity(it.context) }
        if (overlay != null) {
            overlay.animate().cancel()
            overlay.setTag(dismissingTag(overlay.context), null)
            FrostOverlayHostRegistry.panelShellReleaser?.invoke(overlay)
            detachOverlayView(overlay)
        }
        if (host != null && overlay != null) {
            onOverlayDetached(host, overlay)
        }
        notifyDismiss(overlay, resolveOnDismiss(overlay, onDismiss))
    }

    @JvmStatic
    fun findActivity(context: Context?): Activity? {
        var ctx = context
        while (ctx is ContextWrapper) {
            if (ctx is Activity) {
                return ctx
            }
            ctx = ctx.baseContext
        }
        val top = ActivityUtils.getTopActivity()
        if (top != null && !top.isFinishing && !top.isDestroyed) {
            return top
        }
        return null
    }

    private fun resolveOnDismiss(overlay: View?, explicit: Runnable?): Runnable? {
        if (explicit != null) {
            return explicit
        }
        if (overlay == null) {
            return null
        }
        val tag = overlay.getTag(onDismissTag(overlay.context))
        return tag as? Runnable
    }

    private fun notifyDismiss(overlay: View?, onDismiss: Runnable?) {
        if (onDismiss == null) {
            return
        }
        if (overlay != null) {
            val callbackTag = dismissCallbackTag(overlay.context)
            if (overlay.getTag(callbackTag) == true) {
                return
            }
            overlay.setTag(callbackTag, true)
            overlay.setTag(onDismissTag(overlay.context), null)
        }
        onDismiss.run()
    }

    private fun findTopOverlay(session: ActivitySession): View? {
        val contentRoot = session.activity.findViewById<ViewGroup>(android.R.id.content)
            ?: return null
        val rootId = frostedGlassRootId(session.activity)
        for (i in contentRoot.childCount - 1 downTo 0) {
            val child = contentRoot.getChildAt(i)
            if (child.id == rootId) {
                return child
            }
        }
        return null
    }

    private fun hasAttachedOverlay(session: ActivitySession): Boolean {
        pruneDeadOverlays(session)
        return session.overlays.isNotEmpty()
    }

    private fun onOverlayDetached(activity: Activity, overlay: View) {
        val session = sessions[activity] ?: return
        var wasTracked = false
        val iterator = session.overlays.iterator()
        while (iterator.hasNext()) {
            val candidate = iterator.next().get()
            if (candidate == null) {
                iterator.remove()
                continue
            }
            if (candidate === overlay) {
                wasTracked = true
                iterator.remove()
            }
        }
        if (!wasTracked) {
            return
        }
        pruneDeadOverlays(session)
        session.overlayCount = session.overlays.size
        if (!hasAttachedOverlay(session)) {
            session.overlayCount = 0
            unfreezePageBackdropsDuringOverlay(session)
            releaseFrozenBackdrop(session)
            FrostCardBlurRegistry.onAllOverlaysDismissed?.invoke(activity)
            sessions.remove(activity)
        }
        maintainImmersiveSystemUi(activity)
    }

    private fun pruneDeadOverlays(session: ActivitySession) {
        val iterator = session.overlays.iterator()
        while (iterator.hasNext()) {
            val overlay = iterator.next().get()
            if (overlay == null || overlay.parent !is ViewGroup) {
                iterator.remove()
            }
        }
    }

    private fun removeOrphanOverlays(contentRoot: ViewGroup, activity: Activity) {
        val rootId = frostedGlassRootId(activity)
        for (i in contentRoot.childCount - 1 downTo 0) {
            val child = contentRoot.getChildAt(i)
            if (child.id == rootId) {
                dismissImmediate(activity, child, null)
            }
        }
    }

    private fun ensureBlurTargetRestored(contentRoot: ViewGroup?) {
        // Legacy dynamic BlurTarget wrapping is removed; unwrap any stale FrostCaptureTarget shell.
        if (contentRoot == null || contentRoot.childCount == 0) {
            return
        }
        val firstChild = contentRoot.getChildAt(0)
        if (firstChild !is FrostCaptureTarget || firstChild.childCount != 1) {
            return
        }
        val wrapped = firstChild.getChildAt(0)
        firstChild.removeView(wrapped)
        contentRoot.removeView(firstChild)
        contentRoot.addView(wrapped, 0)
    }

    private fun resolveOverlay(activity: Activity?, overlayHint: View?): View? {
        if (overlayHint != null) {
            return overlayHint
        }
        if (activity == null) {
            return null
        }
        val session = sessions[activity] ?: return null
        return findTopOverlay(session)
    }

    private fun playFadeIn(overlay: View, onEnd: (() -> Unit)? = null) {
        overlay.alpha = 0f
        overlay.animate().cancel()
        val duration = FrostDimens.fadeInDurationMs(overlay.context)
        var finished = false
        val finishOnce = Runnable {
            if (finished) {
                return@Runnable
            }
            finished = true
            onEnd?.invoke()
        }
        overlay.animate()
            .alpha(1f)
            .setDuration(duration.toLong())
            .setInterpolator(DecelerateInterpolator())
            .withEndAction { finishOnce.run() }
            .start()
        overlay.postDelayed(finishOnce, duration + 32L)
    }

    private fun detachOverlayView(overlay: View?) {
        if (overlay == null) {
            return
        }
        val parent = overlay.parent as? ViewGroup ?: return
        parent.removeView(overlay)
    }

    private fun configureCardLayout(overlay: View, activity: Activity, cardWidth: CardWidth) {
        val cardId = FrostResourceIds.viewId(activity, "frost_dialog_content")
        val card = overlay.findViewById<View>(cardId) ?: return
        val layoutParams = card.layoutParams
        if (layoutParams !is FrameLayout.LayoutParams) {
            return
        }
        val frameParams = layoutParams
        val inset = cardWidth.getContentInsetPx()
        if (inset > 0) {
            frameParams.setMargins(inset, inset, inset, inset)
            frameParams.width = cardWidth.resolvePx(activity)
            frameParams.height = cardWidth.resolveHeightPx(activity)
            frameParams.gravity = Gravity.CENTER
            card.layoutParams = frameParams
            applyFixedHeightShellLayout(overlay, activity)
            if (cardWidth.shouldExpandBodyScroll()) {
                applyBodyScrollExpansion(overlay, activity)
            }
            return
        }
        if (cardWidth.getMinHeightPx() > 0) {
            card.minimumHeight = cardWidth.getMinHeightPx()
        }
        frameParams.setMargins(0, 0, 0, 0)
        frameParams.width = cardWidth.resolvePx(activity)
        if (cardWidth.hasFixedHeight()) {
            frameParams.height = cardWidth.resolveHeightPx(activity)
            applyFixedHeightShellLayout(overlay, activity)
            if (cardWidth.shouldExpandBodyScroll()) {
                applyBodyScrollExpansion(overlay, activity)
            }
        }
        frameParams.gravity = Gravity.CENTER
        card.layoutParams = frameParams
        applyMaxHeightIfNeeded(overlay, card, cardWidth, activity)
    }

    private fun applyMaxHeightIfNeeded(
        overlay: View,
        card: View,
        cardWidth: CardWidth,
        activity: Activity,
    ) {
        val maxHeightPx = cardWidth.getMaxHeightPx()
        if (maxHeightPx <= 0 || cardWidth.hasFixedHeight()) {
            return
        }
        card.viewTreeObserver.addOnGlobalLayoutListener(object : ViewTreeObserver.OnGlobalLayoutListener {
            override fun onGlobalLayout() {
                card.viewTreeObserver.removeOnGlobalLayoutListener(this)
                if (card.height <= maxHeightPx) {
                    return
                }
                val layoutParams = card.layoutParams
                if (layoutParams is FrameLayout.LayoutParams) {
                    layoutParams.height = maxHeightPx
                    card.layoutParams = layoutParams
                }
                applyFixedHeightShellLayout(overlay, activity)
                if (cardWidth.shouldExpandBodyScroll()) {
                    applyBodyScrollExpansion(overlay, activity)
                    expandCustomBodyToFill(overlay, activity)
                }
            }
        })
    }

    private fun expandCustomBodyToFill(overlay: View, context: Context) {
        val bodySlotId = FrostResourceIds.viewId(context, "frost_dialog_body_slot")
        val bodySlot = overlay.findViewById<View>(bodySlotId)
        if (bodySlot !is ViewGroup || bodySlot.childCount == 0) {
            return
        }
        val bodyChild = bodySlot.getChildAt(0)
        val layoutParams = bodyChild.layoutParams
        layoutParams.height = ViewGroup.LayoutParams.MATCH_PARENT
        bodyChild.layoutParams = layoutParams
    }

    private fun applyFixedHeightShellLayout(overlay: View, context: Context) {
        setMatchParentHeight(overlay.findViewById(FrostResourceIds.viewId(context, "frost_dialog_panel")))
        setMatchParentHeight(
            overlay.findViewById(FrostResourceIds.viewId(context, "frost_dialog_backdrop_clip")),
        )
        val foreground = overlay.findViewById<View>(
            FrostResourceIds.viewId(context, "frost_dialog_light_foreground"),
        )
        if (foreground != null) {
            val params = foreground.layoutParams
            params.height = ViewGroup.LayoutParams.MATCH_PARENT
            foreground.layoutParams = params
        }
    }

    private fun applyBodyScrollExpansion(overlay: View, context: Context) {
        val bodySlot = overlay.findViewById<View>(
            FrostResourceIds.viewId(context, "frost_dialog_body_slot"),
        ) ?: return
        val bodyParams = bodySlot.layoutParams as? LinearLayout.LayoutParams ?: return
        bodyParams.height = 0
        bodyParams.weight = 1f
        bodySlot.layoutParams = bodyParams
    }

    private fun setMatchParentHeight(view: View?) {
        if (view == null) {
            return
        }
        val params = view.layoutParams
        params.height = ViewGroup.LayoutParams.MATCH_PARENT
        view.layoutParams = params
    }

    private fun scheduleFrozenBackdropCapture(session: ActivitySession, contentRoot: ViewGroup) {
        if (session.overlayCount == 0 ||
            session.capturePolicy != FrostBackdropCapturePolicy.AUTO_AFTER_LAYOUT
        ) {
            return
        }
        if (session.frozenBackdrop != null) {
            applyFrozenBackdropToOverlays(session)
            return
        }
        clearScheduledBackdropCapture(session)
        var framesRemaining = BACKDROP_CAPTURE_FRAME_WAIT
        var attempts = 0
        val listener = object : ViewTreeObserver.OnPreDrawListener {
            override fun onPreDraw(): Boolean {
                if (session.overlayCount == 0 ||
                    session.capturePolicy != FrostBackdropCapturePolicy.AUTO_AFTER_LAYOUT ||
                    session.frozenBackdrop != null
                ) {
                    clearScheduledBackdropCapture(session)
                    return true
                }
                if (framesRemaining > 0) {
                    framesRemaining--
                    return true
                }
                val card = findDialogCard(session)
                val cardReady = card != null && card.width > 0 && card.height > 0
                when (resolveInitialFrostBackdropCaptureDecision(
                    cardReady = cardReady,
                    attempts = attempts,
                    maxAttempts = INITIAL_LOCAL_CAPTURE_MAX_ATTEMPTS,
                )) {
                    FrostInitialCaptureDecision.WAIT_FOR_LAYOUT -> {
                        attempts++
                    }
                    FrostInitialCaptureDecision.CAPTURE_LOCAL -> {
                        val initialMode = if (session.preferFullscreenDialogCapture) {
                            FrostBackdropDisplayMode.FULLSCREEN
                        } else {
                            FrostBackdropDisplayMode.LOCAL
                        }
                        val accepted = requestFrozenBackdropCapture(
                            session,
                            contentRoot,
                            FrostBackdropCaptureRequest(
                                reason = FrostBackdropCaptureReason.INITIAL,
                                mode = initialMode,
                                execution = FrostBackdropCaptureExecution.ASYNC,
                                forceReapply = true,
                            ),
                        )
                        if (accepted) {
                            clearScheduledBackdropCapture(session)
                        } else {
                            attempts++
                        }
                    }
                    FrostInitialCaptureDecision.CAPTURE_FULLSCREEN_FALLBACK -> {
                        Log.w(
                            TAG,
                            "initial local capture unavailable after $attempts attempts; " +
                                "using fullscreen fallback",
                        )
                        requestFrozenBackdropCapture(
                            session,
                            contentRoot,
                            FrostBackdropCaptureRequest(
                                reason = FrostBackdropCaptureReason.RETRY,
                                mode = FrostBackdropDisplayMode.FULLSCREEN,
                                execution = FrostBackdropCaptureExecution.ASYNC,
                                forceReapply = true,
                            ),
                        )
                        clearScheduledBackdropCapture(session)
                    }
                }
                return true
            }
        }
        session.backdropPreDrawRoot = WeakReference(contentRoot)
        session.backdropPreDrawListener = listener
        contentRoot.viewTreeObserver.addOnPreDrawListener(listener)
    }

    private fun clearScheduledBackdropCapture(session: ActivitySession) {
        val listener = session.backdropPreDrawListener
        val root = session.backdropPreDrawRoot?.get()
        if (listener != null && root != null) {
            val observer = root.viewTreeObserver
            if (observer.isAlive) {
                observer.removeOnPreDrawListener(listener)
            }
        }
        session.backdropPreDrawListener = null
        session.backdropPreDrawRoot = null
    }

    private data class CapturedBackdrop(
        val bitmap: Bitmap,
        val anchor: FrozenDialogAnchor?,
    )

    /**
     * Single entry point for dialog backdrop capture requests.
     *
     * Phase 0 intentionally preserves the current caller-selected capture mode and sync/async
     * behavior. Later phases can change policy without duplicating lifecycle and logging logic.
     */
    private fun requestFrozenBackdropCapture(
        session: ActivitySession,
        contentRoot: ViewGroup,
        request: FrostBackdropCaptureRequest,
    ): Boolean {
        if (request.surface == FrostBackdropSurface.IME_KEYBOARD &&
            resolveSharedCropSourceForKeyboard(session) != null &&
            applyKeyboardBackdropFromSessionSnapshot(session, contentRoot, request.forceReapply)
        ) {
            Log.d(
                TAG,
                "skip IME_KEYBOARD capture; shared fullscreen crop reason=${request.reason.logValue}",
            )
            return true
        }
        val captureGeneration = beginBackdropCapture(session, request.surface)
        val startedAtMs = SystemClock.elapsedRealtime()
        Log.d(
            TAG,
            "request reason=${request.reason.logValue} policy=${session.capturePolicy} " +
                "mode=${request.mode} execution=${request.execution} " +
                "state=${session.captureState} generation=$captureGeneration",
        )
        return when (request.execution) {
            FrostBackdropCaptureExecution.SYNC -> {
                val captured = captureBackdropSync(session, contentRoot, request)
                if (captured == null) {
                    completeBackdropCaptureFailure(
                        session,
                        request,
                        captureGeneration,
                        startedAtMs,
                        "captureUnavailable",
                    )
                    false
                } else {
                    applyCapturedBackdrop(
                        session,
                        request,
                        captureGeneration,
                        startedAtMs,
                        captured,
                    )
                }
            }
            FrostBackdropCaptureExecution.ASYNC -> {
                val captured = captureBackdropSnapshot(session, contentRoot, request)
                if (captured == null) {
                    completeBackdropCaptureFailure(
                        session,
                        request,
                        captureGeneration,
                        startedAtMs,
                        "snapshotUnavailable",
                    )
                    false
                } else {
                    val blurIntensity = resolveOverlayBlurIntensity(session)
                    val blurFuture = FrostBackdropSnapshot.blurCapturedSnapshotAsync(
                        session.activity,
                        captured.bitmap,
                        blurIntensity,
                    ) { blurred ->
                        if (blurred == null) {
                            completeBackdropCaptureFailure(
                                session,
                                request,
                                captureGeneration,
                                startedAtMs,
                                "blurFailed",
                            )
                            return@blurCapturedSnapshotAsync
                        }
                        applyCapturedBackdrop(
                            session,
                            request,
                            captureGeneration,
                            startedAtMs,
                            CapturedBackdrop(blurred, captured.anchor),
                        )
                    }
                    when (request.surface) {
                        FrostBackdropSurface.DIALOG_CARD -> session.backdropBlurFuture = blurFuture
                        FrostBackdropSurface.IME_KEYBOARD -> session.keyboardBackdropBlurFuture = blurFuture
                    }
                    true
                }
            }
        }
    }

    private fun captureBackdropSync(
        session: ActivitySession,
        contentRoot: ViewGroup,
        request: FrostBackdropCaptureRequest,
    ): CapturedBackdrop? {
        val blurIntensity = resolveOverlayBlurIntensity(session)
        return when (request.mode) {
            FrostBackdropDisplayMode.LOCAL -> {
                val target = resolveCaptureTargetView(session, request.surface) ?: return null
                if (request.surface == FrostBackdropSurface.IME_KEYBOARD &&
                    !isKeyboardCaptureTargetReady(session, target)
                ) {
                    return null
                }
                if (target.width <= 0 || target.height <= 0) {
                    return null
                }
                val anchor = resolveAnchorForView(contentRoot, target) ?: return null
                val drawRoot = FrostBackdropResolver.resolveBackdropSnapshotRoot(contentRoot) ?: return null
                val bitmap = maybeWithPageFrostCardsHidden(drawRoot, request.hidePageFrostCardsDuringCapture) {
                    withDialogOverlaysHidden(session) {
                        FrostBackdropSnapshot.captureAndBlurForCard(
                            contentRoot,
                            target,
                            session.activity,
                            blurIntensity,
                            overscanPx = request.overscanPx,
                        )
                    }
                } ?: return null
                CapturedBackdrop(bitmap, anchor)
            }
            FrostBackdropDisplayMode.FULLSCREEN -> {
                if (contentRoot.width <= 0 || contentRoot.height <= 0) {
                    return null
                }
                val drawRoot = FrostBackdropResolver.resolveBackdropSnapshotRoot(contentRoot) ?: return null
                val bitmap = maybeWithPageFrostCardsHidden(drawRoot, request.hidePageFrostCardsDuringCapture) {
                    withDialogOverlaysHidden(session) {
                        FrostBackdropSnapshot.captureAndBlur(contentRoot, session.activity, blurIntensity)
                    }
                } ?: return null
                CapturedBackdrop(bitmap, null)
            }
        }
    }

    private fun captureBackdropSnapshot(
        session: ActivitySession,
        contentRoot: ViewGroup,
        request: FrostBackdropCaptureRequest,
    ): CapturedBackdrop? {
        return when (request.mode) {
            FrostBackdropDisplayMode.LOCAL -> {
                val target = resolveCaptureTargetView(session, request.surface) ?: return null
                if (request.surface == FrostBackdropSurface.IME_KEYBOARD &&
                    !isKeyboardCaptureTargetReady(session, target)
                ) {
                    return null
                }
                if (target.width <= 0 || target.height <= 0) {
                    return null
                }
                val anchor = resolveAnchorForView(contentRoot, target) ?: return null
                val drawRoot = FrostBackdropResolver.resolveBackdropSnapshotRoot(contentRoot) ?: return null
                val bitmap = maybeWithPageFrostCardsHidden(drawRoot, request.hidePageFrostCardsDuringCapture) {
                    withDialogOverlaysHidden(session) {
                        FrostBackdropCapture.captureRegion(
                            drawRoot,
                            target,
                            FrostBackdropSnapshot.BLUR_SCALE_FACTOR,
                            request.overscanPx,
                        )
                    }
                } ?: return null
                CapturedBackdrop(bitmap, anchor)
            }
            FrostBackdropDisplayMode.FULLSCREEN -> {
                if (contentRoot.width <= 0 || contentRoot.height <= 0) {
                    return null
                }
                val drawRoot = FrostBackdropResolver.resolveBackdropSnapshotRoot(contentRoot) ?: return null
                val bitmap = maybeWithPageFrostCardsHidden(drawRoot, request.hidePageFrostCardsDuringCapture) {
                    withDialogOverlaysHidden(session) {
                        FrostBackdropSnapshot.captureSnapshot(contentRoot)
                    }
                } ?: return null
                CapturedBackdrop(bitmap, null)
            }
        }
    }

    private fun beginBackdropCapture(
        session: ActivitySession,
        surface: FrostBackdropSurface,
    ): Int = when (surface) {
        FrostBackdropSurface.DIALOG_CARD -> {
            session.backdropBlurFuture?.cancel(false)
            session.backdropBlurFuture = null
            session.backdropCaptureGeneration++
            session.captureState = FrostBackdropCaptureStateMachine.onRequest(
                hasFrame = session.frozenBackdrop != null,
            )
            session.backdropCaptureGeneration
        }
        FrostBackdropSurface.IME_KEYBOARD -> {
            session.keyboardBackdropBlurFuture?.cancel(false)
            session.keyboardBackdropBlurFuture = null
            session.keyboardBackdropCaptureGeneration++
            session.keyboardBackdropCaptureGeneration
        }
    }

    private fun currentCaptureGeneration(
        session: ActivitySession,
        surface: FrostBackdropSurface,
    ): Int = when (surface) {
        FrostBackdropSurface.DIALOG_CARD -> session.backdropCaptureGeneration
        FrostBackdropSurface.IME_KEYBOARD -> session.keyboardBackdropCaptureGeneration
    }

    private fun applyCapturedBackdrop(
        session: ActivitySession,
        request: FrostBackdropCaptureRequest,
        captureGeneration: Int,
        startedAtMs: Long,
        captured: CapturedBackdrop,
    ): Boolean {
        if (captureGeneration != currentCaptureGeneration(session, request.surface)) {
            FrostBackdropSnapshot.recycle(captured.bitmap)
            Log.d(
                TAG,
                "dropStale surface=${request.surface} reason=${request.reason.logValue} " +
                    "mode=${request.mode} generation=$captureGeneration " +
                    "current=${currentCaptureGeneration(session, request.surface)}",
            )
            return false
        }
        when (request.surface) {
            FrostBackdropSurface.DIALOG_CARD -> {
                FrostBackdropSnapshot.recycle(session.frozenBackdrop)
                session.frozenBackdrop = captured.bitmap
                session.frozenDialogAnchor = captured.anchor
                session.frozenBackdropGeneration++
                session.frozenBackdropMetadata = FrostBackdropFrameMetadata(
                    mode = request.mode,
                    anchor = captured.anchor,
                    scaleFactor = FrostBackdropSnapshot.BLUR_SCALE_FACTOR,
                    overscanPx = request.overscanPx,
                    generation = session.frozenBackdropGeneration,
                )
                session.captureState = FrostBackdropCaptureStateMachine.onComplete(
                    success = true,
                    hasFrame = true,
                )
                session.backdropBlurFuture = null
            }
            FrostBackdropSurface.IME_KEYBOARD -> {
                if (!isKeyboardBackdropBitmapReady(session, captured.bitmap)) {
                    Log.w(
                        TAG,
                        "drop IME keyboard backdrop; bitmap too small " +
                            "${captured.bitmap.width}x${captured.bitmap.height}",
                    )
                    FrostBackdropSnapshot.recycle(captured.bitmap)
                    if (isKeyboardVisible(session) && !session.imeBackdropCaptureComplete) {
                        val contentRoot =
                            session.activity.findViewById<ViewGroup>(android.R.id.content)
                        if (contentRoot != null) {
                            scheduleKeyboardBackdropRecapture(session, contentRoot, request.reason)
                        }
                    }
                    return false
                }
                FrostBackdropSnapshot.recycle(session.keyboardFrozenBackdrop)
                session.keyboardFrozenBackdrop = captured.bitmap
                session.keyboardFrozenAnchor = captured.anchor
                session.keyboardFrozenBackdropGeneration++
                session.keyboardFrozenBackdropMetadata = FrostBackdropFrameMetadata(
                    mode = request.mode,
                    anchor = captured.anchor,
                    scaleFactor = FrostBackdropSnapshot.BLUR_SCALE_FACTOR,
                    overscanPx = request.overscanPx,
                    generation = session.keyboardFrozenBackdropGeneration,
                )
                session.keyboardBackdropBlurFuture = null
            }
        }
        val elapsedMs = SystemClock.elapsedRealtime() - startedAtMs
        val anchorLog = captured.anchor?.let {
            "${it.widthPx}x${it.heightPx}@${it.leftPx},${it.topPx}"
        } ?: "none"
        Log.d(
            TAG,
            "apply surface=${request.surface} reason=${request.reason.logValue} mode=${request.mode} " +
                "execution=${request.execution} generation=$captureGeneration " +
                "size=${captured.bitmap.width}x${captured.bitmap.height} " +
                "anchor=$anchorLog elapsedMs=$elapsedMs",
        )
        if (request.applyToOverlays && session.overlayCount > 0) {
            when (request.surface) {
                FrostBackdropSurface.DIALOG_CARD -> {
                    applyFrozenBackdropToOverlays(session, forceReapply = request.forceReapply)
                    if (request.mode == FrostBackdropDisplayMode.FULLSCREEN) {
                        retainPageFrozenBackdrop(session, captured.bitmap)
                    } else if (session.pageFrozenBackdrop == null &&
                        request.reason != FrostBackdropCaptureReason.IME_STABLE &&
                        request.reason != FrostBackdropCaptureReason.BOUNDS_CHANGED
                    ) {
                        val contentRoot =
                            session.activity.findViewById<ViewGroup>(android.R.id.content)
                        if (contentRoot != null) {
                            ensurePageFrozenBackdrop(session, contentRoot)
                        }
                    }
                    if (request.reason == FrostBackdropCaptureReason.IME_STABLE) {
                        session.awaitingImeBackdropCapture = false
                    }
                }
                FrostBackdropSurface.IME_KEYBOARD -> {
                    applyKeyboardFrozenBackdropToOverlays(session)
                    if (request.reason == FrostBackdropCaptureReason.IME_STABLE &&
                        session.frozenBackdrop != null &&
                        isKeyboardBackdropReady(session)
                    ) {
                        session.imeBackdropCaptureComplete = true
                        session.awaitingImeBackdropCapture = false
                    }
                }
            }
        }
        return true
    }

    private fun completeBackdropCaptureFailure(
        session: ActivitySession,
        request: FrostBackdropCaptureRequest,
        captureGeneration: Int,
        startedAtMs: Long,
        failure: String,
    ) {
        if (captureGeneration != currentCaptureGeneration(session, request.surface)) {
            return
        }
        when (request.surface) {
            FrostBackdropSurface.DIALOG_CARD -> {
                session.captureState = FrostBackdropCaptureStateMachine.onComplete(
                    success = false,
                    hasFrame = session.frozenBackdrop != null,
                )
                session.backdropBlurFuture = null
            }
            FrostBackdropSurface.IME_KEYBOARD -> {
                session.keyboardBackdropBlurFuture = null
                if (isKeyboardVisible(session) && !session.imeBackdropCaptureComplete) {
                    val contentRoot =
                        session.activity.findViewById<ViewGroup>(android.R.id.content)
                    if (contentRoot != null) {
                        scheduleKeyboardBackdropRecapture(session, contentRoot, request.reason)
                    }
                }
            }
        }
        Log.w(
            TAG,
            "captureFailed surface=${request.surface} reason=${request.reason.logValue} " +
                "mode=${request.mode} execution=${request.execution} generation=$captureGeneration " +
                "state=${session.captureState} failure=$failure " +
                "elapsedMs=${SystemClock.elapsedRealtime() - startedAtMs}",
        )
    }

    private fun scheduleOverlayBackdropRecapture(
        session: ActivitySession,
        contentRoot: ViewGroup,
        reason: FrostBackdropCaptureReason,
    ) {
        val decor = session.activity.window?.decorView ?: return
        session.pendingOverlayRecaptureRunnable?.let { decor.removeCallbacks(it) }
        val runnable = Runnable {
            session.pendingOverlayRecaptureRunnable = null
            if (session.overlayCount == 0) {
                return@Runnable
            }
            executeOverlayBackdropRecapture(session, contentRoot, reason)
        }
        session.pendingOverlayRecaptureRunnable = runnable
        Log.d(TAG, "schedule overlay recapture reason=${reason.logValue} debounce=${OVERLAY_BACKDROP_RECAPTURE_DEBOUNCE_MS}ms")
        decor.postDelayed(runnable, OVERLAY_BACKDROP_RECAPTURE_DEBOUNCE_MS)
    }

    private fun scheduleKeyboardBackdropRecapture(
        session: ActivitySession,
        contentRoot: ViewGroup,
        reason: FrostBackdropCaptureReason,
    ) {
        val decor = session.activity.window?.decorView ?: return
        val runnable = Runnable {
            if (session.overlayCount == 0 || !isKeyboardVisible(session)) {
                return@Runnable
            }
            refreshKeyboardFrozenBackdrop(session.activity)
        }
        Log.d(TAG, "schedule keyboard recapture reason=${reason.logValue} debounce=${OVERLAY_BACKDROP_RECAPTURE_DEBOUNCE_MS}ms")
        decor.postDelayed(runnable, OVERLAY_BACKDROP_RECAPTURE_DEBOUNCE_MS)
    }

    private fun executeOverlayBackdropRecapture(
        session: ActivitySession,
        contentRoot: ViewGroup,
        reason: FrostBackdropCaptureReason,
    ) {
        if (reason == FrostBackdropCaptureReason.IME_STABLE && session.imeBackdropCaptureComplete) {
            return
        }
        if (session.deferFrozenBackdropUntilManualCapture && session.frozenBackdrop == null) {
            return
        }
        val card = findDialogCard(session)
        val cardReady = card != null && card.width > 0 && card.height > 0
        val dialogAnchor = if (cardReady) resolveAnchorForView(contentRoot, card!!) else null
        val shouldRecaptureDialog = cardReady && when {
            session.frozenBackdrop == null -> true
            dialogAnchor == null -> false
            session.frozenBackdropMetadata?.mode == FrostBackdropDisplayMode.FULLSCREEN &&
                (reason == FrostBackdropCaptureReason.IME_STABLE ||
                    reason == FrostBackdropCaptureReason.BOUNDS_CHANGED ||
                    !dialogAnchor.matchesScreenBounds(session.frozenDialogAnchor)) -> {
                realignFullscreenDialogBackdrop(session, dialogAnchor)
                false
            }
            !dialogAnchor.matchesScreenBounds(session.frozenDialogAnchor) -> !session.imeBackdropCaptureComplete
            reason == FrostBackdropCaptureReason.IME_STABLE -> !session.imeBackdropCaptureComplete
            reason == FrostBackdropCaptureReason.BOUNDS_CHANGED ->
                !session.imeBackdropCaptureComplete && !isKeyboardVisible(session)
            else -> false
        }
        if (shouldRecaptureDialog) {
            ensurePageFrozenBackdrop(session, contentRoot)
            if (isKeyboardVisible(session) && dialogAnchor != null &&
                applyDialogBackdropCropFromPageSnapshot(session, dialogAnchor, forceReapply = true)
            ) {
                Log.d(TAG, "skip dialog live recapture; cropped from frozen page reason=${reason.logValue}")
            } else {
                requestFrozenBackdropCapture(
                    session,
                    contentRoot,
                    FrostBackdropCaptureRequest(
                        reason = reason,
                        mode = FrostBackdropDisplayMode.LOCAL,
                        execution = FrostBackdropCaptureExecution.ASYNC,
                        surface = FrostBackdropSurface.DIALOG_CARD,
                        forceReapply = true,
                        hidePageFrostCardsDuringCapture = !isKeyboardVisible(session),
                    ),
                )
            }
        }
        if (!isKeyboardVisible(session)) {
            return
        }
        val keyboardTarget = findImeKeyboardCaptureTarget(session) ?: return
        if (!isKeyboardCaptureTargetReady(session, keyboardTarget)) {
            if (isKeyboardVisible(session)) {
                scheduleKeyboardBackdropRecapture(session, contentRoot, reason)
            }
            return
        }
        val keyboardAnchor = resolveAnchorForView(contentRoot, keyboardTarget) ?: return
        val shouldRecaptureKeyboard = when {
            resolveSharedCropSourceForKeyboard(session) != null -> {
                session.keyboardFrozenAnchor = keyboardAnchor
                applyKeyboardFrozenBackdropToOverlays(session, forceReapply = true)
                Log.d(TAG, "keyboard crop from shared fullscreen reason=${reason.logValue}")
                false
            }
            session.keyboardFrozenBackdrop == null -> !session.imeBackdropCaptureComplete
            !keyboardAnchor.matchesScreenBounds(session.keyboardFrozenAnchor) ->
                !session.imeBackdropCaptureComplete
            reason == FrostBackdropCaptureReason.IME_STABLE -> !session.imeBackdropCaptureComplete
            reason == FrostBackdropCaptureReason.BOUNDS_CHANGED ->
                !session.imeBackdropCaptureComplete && !isKeyboardVisible(session)
            else -> false
        }
        if (shouldRecaptureKeyboard) {
            requestFrozenBackdropCapture(
                session,
                contentRoot,
                FrostBackdropCaptureRequest(
                    reason = reason,
                    mode = FrostBackdropDisplayMode.LOCAL,
                    execution = FrostBackdropCaptureExecution.ASYNC,
                    surface = FrostBackdropSurface.IME_KEYBOARD,
                    forceReapply = true,
                    hidePageFrostCardsDuringCapture = false,
                ),
            )
        }
    }

    private fun resolveCaptureTargetView(
        session: ActivitySession,
        surface: FrostBackdropSurface,
    ): View? = when (surface) {
        FrostBackdropSurface.DIALOG_CARD -> findDialogCard(session)
        FrostBackdropSurface.IME_KEYBOARD -> findImeKeyboardCaptureTarget(session)
    }

    private fun findImeKeyboardCaptureTarget(session: ActivitySession): View? {
        val overlay = findTopOverlay(session) ?: return null
        val slotId = FrostResourceIds.viewId(session.activity, "frost_dialog_ime_slot")
        val slot = overlay.findViewById<ViewGroup>(slotId) ?: return null

        for (index in 0 until slot.childCount) {
            val child = slot.getChildAt(index)
            if (child is ImeKeyboardBackdropHost) {
                return child
            }
        }

        return null
    }

    private fun isKeyboardVisible(session: ActivitySession): Boolean {
        val overlay = findTopOverlay(session) ?: return false
        val slotId = FrostResourceIds.viewId(session.activity, "frost_dialog_ime_slot")
        val slot = overlay.findViewById<ViewGroup>(slotId) ?: return false
        return slot.childCount > 0
    }

    private fun minKeyboardCaptureTargetHeightPx(activity: Activity): Int {
        val panelHeight = ImeKeyboardOverlay.panelHeightPx(activity)
        return (panelHeight * 0.6f).roundToInt()
    }

    private fun minKeyboardBackdropBitmapHeightPx(activity: Activity): Int {
        val panelHeight = ImeKeyboardOverlay.panelHeightPx(activity)
        return maxOf(
            8,
            (panelHeight / FrostBackdropSnapshot.BLUR_SCALE_FACTOR * 0.6f).roundToInt(),
        )
    }

    private fun isKeyboardCaptureTargetReady(session: ActivitySession, target: View): Boolean {
        val minHeight = minKeyboardCaptureTargetHeightPx(session.activity)
        return target.width > 0 && target.height >= minHeight
    }

    private fun isKeyboardBackdropBitmapReady(session: ActivitySession, bitmap: Bitmap): Boolean {
        if (bitmap.isRecycled) {
            return false
        }
        return bitmap.height >= minKeyboardBackdropBitmapHeightPx(session.activity)
    }

    private fun isKeyboardBackdropReady(session: ActivitySession): Boolean {
        val minBitmapHeight = minKeyboardBackdropBitmapHeightPx(session.activity)
        session.keyboardFrozenBackdrop
            ?.takeIf { !it.isRecycled && it.height >= minBitmapHeight }
            ?.let { return true }
        val host = findImeKeyboardCaptureTarget(session) as? ImeKeyboardBackdropHost ?: return false
        return host.hasValidBackdrop(minBitmapHeight)
    }

    private fun resolveAnchorForView(contentRoot: ViewGroup, target: View): FrozenDialogAnchor? {
        if (target.width <= 0 || target.height <= 0) {
            return null
        }
        val contentLoc = IntArray(2)
        val targetLoc = IntArray(2)
        contentRoot.getLocationOnScreen(contentLoc)
        target.getLocationOnScreen(targetLoc)
        return FrozenDialogAnchor(
            leftPx = targetLoc[0] - contentLoc[0],
            topPx = targetLoc[1] - contentLoc[1],
            widthPx = target.width,
            heightPx = target.height,
        )
    }

    private fun realignFullscreenDialogBackdrop(
        session: ActivitySession,
        dialogAnchor: FrozenDialogAnchor,
    ) {
        session.frozenDialogAnchor = dialogAnchor
        applyFrozenBackdropToOverlays(session, forceReapply = true)
        Log.d(
            TAG,
            "realignFullscreenDialog anchor=${dialogAnchor.widthPx}x${dialogAnchor.heightPx}" +
                "@${dialogAnchor.leftPx},${dialogAnchor.topPx}",
        )
    }

    /** Matrix-only realign for a frozen FULLSCREEN frame (boot self-check row growth, IME lift). */
    private fun realignFullscreenDialogBackdropOnBoundsChanged(
        session: ActivitySession,
        activity: Activity,
    ) {
        val contentRoot = activity.findViewById<ViewGroup>(android.R.id.content) ?: return
        val card = findDialogCard(session)
        if (card != null && card.width > 0 && card.height > 0) {
            resolveAnchorForView(contentRoot, card)?.let { anchor ->
                session.frozenDialogAnchor = anchor
            }
        }
        applyFrozenBackdropToOverlays(session, forceReapply = true)
        if (isKeyboardVisible(session)) {
            applyKeyboardFrozenBackdropToOverlays(session, forceReapply = true)
        }
        for (ref in session.overlays) {
            val overlay = ref.get() ?: continue
            val cardId = FrostResourceIds.viewId(activity, "frost_dialog_content")
            val frostCard = overlay.findViewById<View>(cardId) as? FrostCardView ?: continue
            frostCard.syncStaticBackdropMatrix()
        }
        Log.d(TAG, "realignFullscreenDialogOnBoundsChanged generation=${session.frozenBackdropGeneration}")
    }

    private fun promotePageFrozenToDialogFrozen(session: ActivitySession): Boolean {
        val page = session.pageFrozenBackdrop?.takeIf { !it.isRecycled } ?: return false
        session.frozenBackdrop = page.copy(page.config ?: Bitmap.Config.ARGB_8888, false)
        session.frozenDialogAnchor = null
        session.frozenBackdropGeneration++
        session.frozenBackdropMetadata = FrostBackdropFrameMetadata(
            mode = FrostBackdropDisplayMode.FULLSCREEN,
            anchor = null,
            scaleFactor = FrostBackdropSnapshot.BLUR_SCALE_FACTOR,
            overscanPx = 0,
            generation = session.frozenBackdropGeneration,
        )
        session.captureState = FrostBackdropCaptureStateMachine.onComplete(
            success = true,
            hasFrame = true,
        )
        Log.d(
            TAG,
            "promotePageFrozenToDialogFrozen generation=${session.frozenBackdropGeneration}",
        )
        return true
    }

    private fun capturePageFrozenBackdropOnce(
        session: ActivitySession,
        contentRoot: ViewGroup,
        activity: Activity,
    ) {
        if (session.pageFrozenBackdrop?.isRecycled == false) {
            return
        }
        val blurIntensity = resolveOverlayBlurIntensity(session)
        val captured = FrostBackdropSnapshot.captureAndBlur(contentRoot, activity, blurIntensity)
            ?: return
        retainPageFrozenBackdrop(session, captured)
        Log.d(
            TAG,
            "capturePageFrozenBackdropOnce size=${captured.width}x${captured.height} " +
                "generation=${session.pageFrozenBackdropGeneration}",
        )
    }

    private fun captureSyncFullscreenBackdrop(
        session: ActivitySession,
        contentRoot: ViewGroup,
        activity: Activity,
        blurIntensity: FrostBlurIntensity,
    ): Boolean {
        val captured = FrostBackdropSnapshot.captureAndBlur(contentRoot, activity, blurIntensity)
            ?: return false
        session.frozenBackdrop = captured
        session.frozenDialogAnchor = null
        session.frozenBackdropGeneration++
        retainPageFrozenBackdrop(session, captured)
        session.frozenBackdropMetadata = FrostBackdropFrameMetadata(
            mode = FrostBackdropDisplayMode.FULLSCREEN,
            anchor = null,
            scaleFactor = FrostBackdropSnapshot.BLUR_SCALE_FACTOR,
            overscanPx = 0,
            generation = session.frozenBackdropGeneration,
        )
        session.captureState = FrostBackdropCaptureStateMachine.onComplete(
            success = true,
            hasFrame = true,
        )
        Log.d(
            TAG,
            "attachOverlay syncFullscreen size=${captured.width}x${captured.height} " +
                "intensity=$blurIntensity generation=${session.frozenBackdropGeneration}",
        )
        return true
    }

    private fun applyKeyboardFrozenBackdropToOverlays(
        session: ActivitySession,
        forceReapply: Boolean = false,
    ) {
        val contentRoot = session.activity.findViewById<ViewGroup>(android.R.id.content) ?: return
        if (!applyKeyboardBackdropFromSessionSnapshot(session, contentRoot, forceReapply)) {
            val bitmap = session.keyboardFrozenBackdrop ?: return
            applyKeyboardBitmapToOverlays(session, bitmap, session.keyboardFrozenBackdropGeneration, forceReapply)
        }
    }

    /**
     * Crops the keyboard panel from the dialog's frozen full-window snapshot (same sample as the card).
     */
    private fun applyKeyboardBackdropFromSessionSnapshot(
        session: ActivitySession,
        contentRoot: ViewGroup,
        forceReapply: Boolean = false,
    ): Boolean {
        val frozen = resolveSharedCropSourceForKeyboard(session) ?: return false
        val keyboardTarget = findImeKeyboardCaptureTarget(session) ?: return false
        if (!isKeyboardCaptureTargetReady(session, keyboardTarget)) {
            Log.d(
                TAG,
                "skip keyboard crop; target not laid out ${keyboardTarget.width}x${keyboardTarget.height}",
            )
            return false
        }
        val anchor = resolveAnchorForView(contentRoot, keyboardTarget) ?: return false
        session.keyboardFrozenAnchor = anchor
        val cropped = FrostBackdropSnapshot.cropToContentRect(
            frozen,
            anchor.leftPx,
            anchor.topPx,
            anchor.widthPx,
            anchor.heightPx,
        ) ?: return false
        if (!isKeyboardBackdropBitmapReady(session, cropped)) {
            Log.w(
                TAG,
                "skip keyboard crop; bitmap too small ${cropped.width}x${cropped.height}",
            )
            if (cropped !== frozen && !cropped.isRecycled) {
                cropped.recycle()
            }
            return false
        }
        val generation = when (session.frozenBackdropMetadata?.mode) {
            FrostBackdropDisplayMode.FULLSCREEN -> session.frozenBackdropGeneration
            else -> session.pageFrozenBackdropGeneration
        }
        val applied = applyKeyboardBitmapToOverlays(
            session,
            cropped,
            generation,
            forceReapply = true,
        )
        if (cropped !== frozen && !cropped.isRecycled) {
            cropped.recycle()
        }
        return applied
    }

    private fun applyKeyboardBitmapToOverlays(
        session: ActivitySession,
        bitmap: Bitmap,
        generation: Int,
        forceReapply: Boolean,
    ): Boolean {
        if (!isKeyboardBackdropBitmapReady(session, bitmap)) {
            return false
        }
        val blurIntensity = resolveOverlayBlurIntensity(session)
        val overlay = findTopOverlay(session) ?: return false
        val slotId = FrostResourceIds.viewId(session.activity, "frost_dialog_ime_slot")
        val slot = overlay.findViewById<ViewGroup>(slotId) ?: return false
        var applied = false
        for (index in 0 until slot.childCount) {
            val child = slot.getChildAt(index)
            if (child is ImeKeyboardBackdropHost) {
                child.applyLocalBackdrop(
                    bitmap,
                    generation,
                    blurIntensity,
                    forceReapply,
                )
                applied = true
            }
        }
        return applied
    }

    private fun releaseKeyboardFrozenBackdrop(session: ActivitySession) {
        session.imeBackdropCaptureComplete = false
        session.keyboardBackdropBlurFuture?.cancel(false)
        session.keyboardBackdropBlurFuture = null
        session.keyboardBackdropCaptureGeneration++
        FrostBackdropSnapshot.recycle(session.keyboardFrozenBackdrop)
        session.keyboardFrozenBackdrop = null
        session.keyboardFrozenAnchor = null
        session.keyboardFrozenBackdropMetadata = null
        session.keyboardFrozenBackdropGeneration = 0
        val overlay = findTopOverlay(session) ?: return
        val slotId = FrostResourceIds.viewId(session.activity, "frost_dialog_ime_slot")
        val slot = overlay.findViewById<ViewGroup>(slotId) ?: return
        for (index in 0 until slot.childCount) {
            val child = slot.getChildAt(index)
            if (child is ImeKeyboardBackdropHost) {
                child.clearBackdrop()
            }
        }
    }

    private fun invalidateBackdropCapture(session: ActivitySession, reason: String) {
        session.backdropCaptureGeneration++
        session.backdropBlurFuture?.cancel(false)
        session.backdropBlurFuture = null
        session.captureState = FrostBackdropCaptureStateMachine.onComplete(
            success = false,
            hasFrame = session.frozenBackdrop != null,
        )
        Log.d(
            TAG,
            "invalidate reason=$reason generation=${session.backdropCaptureGeneration} " +
                "state=${session.captureState}",
        )
    }

    private fun clearDisplayedBackdropOnOverlays(session: ActivitySession) {
        val cardId = FrostResourceIds.viewId(session.activity, "frost_dialog_content")
        for (ref in session.overlays) {
            val overlay = ref.get() ?: continue
            val card = overlay.findViewById<View>(cardId)
            if (card is FrostCardView) {
                card.clearDisplayedBackdropForRecapture()
            }
        }
    }

    private fun findDialogCard(session: ActivitySession): View? {
        val overlay = findTopOverlay(session) ?: return null
        val cardId = FrostResourceIds.viewId(session.activity, "frost_dialog_content")
        return overlay.findViewById(cardId)
    }

    private fun resolveOverlayBlurIntensity(session: ActivitySession): FrostBlurIntensity {
        val card = findDialogCard(session)
        if (card is FrostCardView) {
            return card.blurIntensityForBackdropCapture()
        }
        return FrostBlurIntensity.HIGH
    }

    private inline fun <T> maybeWithPageFrostCardsHidden(
        drawRoot: View,
        hidePageCards: Boolean,
        block: () -> T,
    ): T {
        if (!hidePageCards) {
            return block()
        }
        return withPageFrostCardsHidden(drawRoot, block)
    }

    private inline fun <T> withPageFrostCardsHidden(drawRoot: View, block: () -> T): T {
        val hidden = ArrayList<Pair<View, Int>>()
        collectPageFrostCards(drawRoot, hidden)
        for ((card, _) in hidden) {
            card.visibility = View.INVISIBLE
        }
        try {
            return block()
        } finally {
            for ((card, visibility) in hidden) {
                card.visibility = visibility
            }
        }
    }

    private fun collectPageFrostCards(view: View, out: MutableList<Pair<View, Int>>) {
        if (view is FrostCardView && view.visibility != View.GONE && !isDialogOverlayCard(view)) {
            out.add(view to view.visibility)
        }
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                collectPageFrostCards(view.getChildAt(index), out)
            }
        }
    }

    private fun isDialogOverlayCard(card: View): Boolean {
        val overlayRootId = FrostResourceIds.viewId(card.context, "frost_dialog_root")
        var current: ViewParent? = card.parent
        while (current is View) {
            if (current.id == overlayRootId) {
                return true
            }
            current = current.parent
        }
        return false
    }

    private inline fun <T> withDialogOverlaysHidden(session: ActivitySession, block: () -> T): T {
        if (session.overlays.isEmpty()) {
            return block()
        }
        val hidden = ArrayList<Pair<View, Int>>()
        for (ref in session.overlays) {
            val overlay = ref.get() ?: continue
            hidden.add(overlay to overlay.visibility)
            overlay.visibility = View.INVISIBLE
        }
        try {
            return block()
        } finally {
            for ((overlay, visibility) in hidden) {
                overlay.visibility = visibility
            }
        }
    }

    private fun releaseFrozenBackdrop(session: ActivitySession) {
        val decor = session.activity.window?.decorView
        session.pendingOverlayRecaptureRunnable?.let { runnable ->
            decor?.removeCallbacks(runnable)
        }
        session.pendingOverlayRecaptureRunnable = null
        clearScheduledBackdropCapture(session)
        invalidateBackdropCapture(session, "release")
        releaseKeyboardFrozenBackdrop(session)
        FrostBackdropSnapshot.recycle(session.frozenBackdrop)
        session.frozenBackdrop = null
        session.frozenDialogAnchor = null
        session.frozenBackdropMetadata = null
        session.frozenBackdropGeneration = 0
        FrostBackdropSnapshot.recycle(session.pageFrozenBackdrop)
        session.pageFrozenBackdrop = null
        session.pageFrozenBackdropGeneration = 0
        session.deferFrozenBackdropUntilIme = false
        session.deferFrozenBackdropUntilManualCapture = false
        session.preferFullscreenDialogCapture = false
        session.awaitingImeBackdropCapture = false
        session.capturePolicy = FrostBackdropCapturePolicy.AUTO_AFTER_LAYOUT
        session.captureState = FrostBackdropCaptureState.IDLE
    }

    private fun resolveFrozenDialogAnchor(
        session: ActivitySession,
        contentRoot: ViewGroup,
    ): FrozenDialogAnchor? {
        val overlay = findTopOverlay(session) ?: return null
        val cardId = FrostResourceIds.viewId(session.activity, "frost_dialog_content")
        val card = overlay.findViewById<View>(cardId) ?: return null
        if (card.width <= 0 || card.height <= 0) {
            return null
        }
        val contentLoc = IntArray(2)
        val cardLoc = IntArray(2)
        contentRoot.getLocationOnScreen(contentLoc)
        card.getLocationOnScreen(cardLoc)
        return FrozenDialogAnchor(
            leftPx = cardLoc[0] - contentLoc[0],
            topPx = cardLoc[1] - contentLoc[1],
            widthPx = card.width,
            heightPx = card.height,
        )
    }

    private fun applyFrozenBackdropToOverlays(
        session: ActivitySession,
        forceReapply: Boolean = false,
    ) {
        if (session.frozenBackdrop == null) {
            return
        }
        val cardId = FrostResourceIds.viewId(session.activity, "frost_dialog_content")
        for (ref in session.overlays) {
            val overlay = ref.get() ?: continue
            val card = overlay.findViewById<View>(cardId) ?: continue
            val frostCard = card as? FrostCardView
            if (frostCard != null) {
                if (forceReapply) {
                    frostCard.forceReapplyFrozenBackdrop()
                } else {
                    frostCard.applyFrozenBackdropIfAvailable()
                }
                frostCard.post {
                    frostCard.applyFrozenBackdropIfAvailable()
                    frostCard.syncStaticBackdropMatrix()
                }
                frostCard.syncStaticBackdropMatrix()
            } else {
                val applier = FrostOverlayHostRegistry.frozenBackdropApplier
                if (applier != null) {
                    applier(card)
                } else {
                    Log.w(
                        TAG,
                        "frost_dialog_content is ${card.javaClass.simpleName}, not FrostCardView; " +
                            "frozen backdrop not applied",
                    )
                }
            }
        }
    }

    private fun applyDialogBackdropCropFromPageSnapshot(
        session: ActivitySession,
        dialogAnchor: FrozenDialogAnchor,
        forceReapply: Boolean,
    ): Boolean {
        val pageFrozen = session.pageFrozenBackdrop?.takeIf { !it.isRecycled }
            ?: return false
        val cropped = FrostBackdropSnapshot.cropToContentRect(
            pageFrozen,
            dialogAnchor.leftPx,
            dialogAnchor.topPx,
            dialogAnchor.widthPx,
            dialogAnchor.heightPx,
        ) ?: return false
        FrostBackdropSnapshot.recycle(session.frozenBackdrop)
        session.frozenBackdrop = cropped
        session.frozenDialogAnchor = dialogAnchor
        session.frozenBackdropGeneration++
        session.frozenBackdropMetadata = FrostBackdropFrameMetadata(
            mode = FrostBackdropDisplayMode.LOCAL,
            anchor = dialogAnchor,
            scaleFactor = FrostBackdropSnapshot.BLUR_SCALE_FACTOR,
            overscanPx = 0,
            generation = session.frozenBackdropGeneration,
        )
        applyFrozenBackdropToOverlays(session, forceReapply = forceReapply)
        if (isKeyboardVisible(session)) {
            applyKeyboardFrozenBackdropToOverlays(session, forceReapply = forceReapply)
        }
        return true
    }

    private fun resolveSharedCropSourceForKeyboard(session: ActivitySession): Bitmap? {
        if (session.frozenBackdropMetadata?.mode == FrostBackdropDisplayMode.FULLSCREEN) {
            return session.frozenBackdrop?.takeIf { !it.isRecycled }
        }
        return session.pageFrozenBackdrop?.takeIf { !it.isRecycled }
    }

    private fun retainPageFrozenBackdrop(session: ActivitySession, source: Bitmap) {
        if (source.isRecycled) {
            return
        }
        FrostBackdropSnapshot.recycle(session.pageFrozenBackdrop)
        session.pageFrozenBackdrop = source.copy(source.config ?: Bitmap.Config.ARGB_8888, false)
        session.pageFrozenBackdropGeneration++
        Log.d(
            TAG,
            "retainPageFrozenBackdrop generation=${session.pageFrozenBackdropGeneration} " +
                "size=${session.pageFrozenBackdrop?.width}x${session.pageFrozenBackdrop?.height}",
        )
    }

    private fun ensurePageFrozenBackdrop(session: ActivitySession, contentRoot: ViewGroup) {
        if (session.pageFrozenBackdrop?.isRecycled == false) {
            return
        }
        val blurIntensity = resolveOverlayBlurIntensity(session)
        val drawRoot = FrostBackdropResolver.resolveBackdropSnapshotRoot(contentRoot) ?: return
        val bitmap = maybeWithPageFrostCardsHidden(drawRoot, hidePageCards = false) {
            withDialogOverlaysHidden(session) {
                FrostBackdropSnapshot.captureAndBlur(contentRoot, session.activity, blurIntensity)
            }
        } ?: return
        retainPageFrozenBackdrop(session, bitmap)
    }

    private fun freezePageBackdropsDuringOverlay(session: ActivitySession) {
        val contentRoot = session.activity.findViewById<ViewGroup>(android.R.id.content) ?: return
        val pageRoot = FrostBackdropResolver.resolveBackdropSnapshotRoot(contentRoot) ?: return
        walkPageBackdropsForOverlayFreeze(pageRoot, freeze = true)
    }

    private fun unfreezePageBackdropsDuringOverlay(session: ActivitySession) {
        val contentRoot = session.activity.findViewById<ViewGroup>(android.R.id.content) ?: return
        val pageRoot = FrostBackdropResolver.resolveBackdropSnapshotRoot(contentRoot) ?: return
        walkPageBackdropsForOverlayFreeze(pageRoot, freeze = false)
    }

    private fun walkPageBackdropsForOverlayFreeze(view: View, freeze: Boolean) {
        if (view is FrostCardView && !isDialogOverlayCard(view)) {
            if (freeze) {
                view.freezePageBackdropDuringOverlay()
            } else {
                view.unfreezePageBackdropAfterOverlay()
            }
        }
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                walkPageBackdropsForOverlayFreeze(view.getChildAt(index), freeze)
            }
        }
    }

    private fun maintainImmersiveSystemUi(activity: Activity) {
        FrostOverlayHostRegistry.immersiveSystemUiMaintainer?.invoke(activity)
    }
}
