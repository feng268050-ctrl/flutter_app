package com.lasercyber.lws.frostui.control

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.graphics.drawable.Drawable
import android.graphics.drawable.RippleDrawable
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.animation.DecelerateInterpolator
import com.lasercyber.lws.frostui.common.FrostUiClickSoundRegistry

/**
 * Hold-to-confirm interaction: press starts a reversible ripple; release after fill completes commits.
 * When [Listener.useHoldConfirm] is false, falls back to immediate click with system pressed state.
 */
class FrostHoldConfirmController @JvmOverloads constructor(
    private val target: View,
    appearance: FrostReversibleRippleAppearance? = null,
    private val listener: Listener,
    private val clickSoundEnabled: Boolean = true,
    private val config: FrostHoldConfirmConfig = FrostHoldConfirmConfig.roundedRect(),
) {
    interface Listener {
        /** When true, require hold-until-ripple-complete + release to confirm. */
        fun useHoldConfirm(): Boolean

        /** Gate hold ripple / confirm when preflight fails (e.g. key switch off). */
        fun passesHoldPreflight(): Boolean = true

        fun onConfirm()

        fun onHoldComplete() {}

        fun onImmediateClick() {}

        fun onHoldCancel() {}
    }

    private val touchSlop = ViewConfiguration.get(target.context).scaledTouchSlop.toFloat()
    private val expandInterpolator = DecelerateInterpolator()
    private val appearance = appearance ?: FrostReversibleRippleAppearance.fromContext(target.context)
    private val rippleDrawable = FrostReversibleRippleDrawable(this.appearance)

    private var downX = 0f
    private var downY = 0f
    private var holdProgress = 0f
    private var gestureActive = false
    private var movedBeyondSlop = false
    private var commitReady = false
    private var reversing = false
    private var holdAnimator: ValueAnimator? = null
    private var attached = false
    private var originalForeground: Drawable? = null
    private var pressRippleDrawable: Drawable? = null
    private var rippleClipSurface: FrostRippleClipSurface? = null

    fun attach() {
        if (attached) {
            return
        }
        attached = true
        config.applyViewClip?.invoke(target)
        rippleDrawable.clipPathProvider = config.rippleClipPath
        rippleDrawable.coverRadiusProvider = config.coverRadiusProvider
        pressRippleDrawable = config.pressRippleProvider?.invoke(target)
        originalForeground = target.foreground?.constantState?.newDrawable()?.mutate()
        rippleClipSurface = target as? FrostRippleClipSurface
        if (rippleClipSurface != null) {
            rippleDrawable.clipPathProvider = null
            rippleClipSurface?.bindHoldRipple(rippleDrawable)
            if (pressRippleDrawable != null) {
                target.foreground = pressRippleDrawable
            }
        } else {
            rippleDrawable.callback = target
            target.foreground = rippleDrawable
        }
        target.setOnClickListener(null)
        target.setOnLongClickListener(null)
        // Irregular hit shapes must not rely on View#onTouchEvent (full bounds when clickable).
        target.isClickable = false
        target.isLongClickable = false
        target.setOnTouchListener { view, event ->
            if (!view.isEnabled) {
                return@setOnTouchListener false
            }
            val inside = isWithinHitRegion(event.x, event.y, view)
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    if (!inside) {
                        return@setOnTouchListener false
                    }
                    handleTouch(event)
                    true
                }
                MotionEvent.ACTION_MOVE,
                MotionEvent.ACTION_UP,
                MotionEvent.ACTION_CANCEL,
                -> {
                    if (!gestureActive) {
                        return@setOnTouchListener false
                    }
                    if (!inside && event.actionMasked == MotionEvent.ACTION_MOVE) {
                        // Left the shaped hit region — cancel hold / press.
                        if (listener.useHoldConfirm()) {
                            if (!reversing) {
                                cancelHoldGesture(onFinished = { listener.onHoldCancel() })
                            }
                        } else {
                            gestureActive = false
                            target.isPressed = false
                            restoreHoldRippleForegroundAfterPress()
                        }
                        return@setOnTouchListener true
                    }
                    handleTouch(event)
                    true
                }
                else -> false
            }
        }
    }

    fun release() {
        if (!attached) {
            return
        }
        attached = false
        cancelHoldAnimation()
        resetVisualsImmediately()
        gestureActive = false
        movedBeyondSlop = false
        commitReady = false
        reversing = false
        target.setOnTouchListener(null)
        if (rippleClipSurface != null) {
            rippleClipSurface?.unbindHoldRipple()
            rippleClipSurface = null
            target.foreground = originalForeground
            originalForeground = null
        } else {
            target.foreground = originalForeground
            originalForeground = null
        }
        pressRippleDrawable = null
        rippleDrawable.callback = null
        rippleDrawable.clipPathProvider = null
        rippleDrawable.coverRadiusProvider = null
    }

    private fun isWithinHitRegion(x: Float, y: Float, view: View): Boolean {
        val hitTest = config.hitTest ?: return true
        return hitTest(x, y, view)
    }

    private fun handleTouch(event: MotionEvent) {
        if (listener.useHoldConfirm()) {
            handleHoldConfirmTouch(event)
        } else {
            handleImmediateTouch(event)
        }
    }

    private fun handleImmediateTouch(event: MotionEvent) {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                // Must arm gestureActive so ACTION_UP is delivered (touch listener
                // gates MOVE/UP/CANCEL on this flag; hold path sets it in beginHoldGesture).
                gestureActive = true
                movedBeyondSlop = false
                commitReady = false
                reversing = false
                clearHoldRippleVisuals()
                showPressRippleForeground()
                target.isPressed = true
                updatePressRippleHotspot(event.x, event.y)
            }
            MotionEvent.ACTION_UP -> {
                if (!gestureActive) {
                    return
                }
                gestureActive = false
                target.isPressed = false
                playClickSound()
                listener.onImmediateClick()
                restoreHoldRippleForegroundAfterPress()
            }
            MotionEvent.ACTION_CANCEL -> {
                gestureActive = false
                target.isPressed = false
                restoreHoldRippleForegroundAfterPress()
            }
        }
    }

    private fun clearHoldRippleVisuals() {
        cancelHoldAnimation()
        holdProgress = 0f
        rippleDrawable.progress = 0f
    }

    private fun showPressRippleForeground() {
        val pressRipple = pressRippleDrawable ?: return
        if (rippleClipSurface != null) {
            target.foreground = pressRipple
            return
        }
        rippleDrawable.callback = null
        target.foreground = pressRipple
    }

    private fun updatePressRippleHotspot(x: Float, y: Float) {
        (target.foreground as? RippleDrawable)?.setHotspot(x, y)
    }

    private fun restoreHoldRippleForegroundAfterPress() {
        if (rippleClipSurface != null) {
            if (pressRippleDrawable != null) {
                target.foreground = pressRippleDrawable
            }
            rippleClipSurface?.bindHoldRipple(rippleDrawable)
            return
        }
        rippleDrawable.callback = target
        target.foreground = rippleDrawable
    }

    private fun handleHoldConfirmTouch(event: MotionEvent) {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                if (!listener.passesHoldPreflight()) {
                    return
                }
                beginHoldGesture(event.x, event.y)
            }
            MotionEvent.ACTION_MOVE -> {
                if (!gestureActive || reversing) {
                    return
                }
                if (movedBeyondSlop(event.x, event.y)) {
                    movedBeyondSlop = true
                    cancelHoldGesture(onFinished = { listener.onHoldCancel() })
                }
            }
            MotionEvent.ACTION_UP -> {
                if (!gestureActive || reversing) {
                    return
                }
                finishHoldGesture(canceled = false)
            }
            MotionEvent.ACTION_CANCEL -> {
                if (!gestureActive || reversing) {
                    return
                }
                finishHoldGesture(canceled = true)
            }
        }
    }

    private fun beginHoldGesture(x: Float, y: Float) {
        cancelHoldAnimation()
        resetVisualsImmediately()
        gestureActive = true
        movedBeyondSlop = false
        commitReady = false
        reversing = false
        holdProgress = 0f
        downX = x
        downY = y
        rippleDrawable.originX = x
        rippleDrawable.originY = y
        rippleDrawable.progress = 0f
        animateHoldScale(armed = true)
        startForwardHoldAnimation()
    }

    private fun startForwardHoldAnimation() {
        holdAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = appearance.fillDurationMs
            interpolator = DecelerateInterpolator()
            addUpdateListener { updateHoldProgress(it.animatedValue as Float) }
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    if (!gestureActive || movedBeyondSlop || reversing) {
                        return
                    }
                    commitReady = true
                    listener.onHoldComplete()
                }
            })
            start()
        }
    }

    private fun reverseHoldAnimation(onEnd: () -> Unit) {
        cancelHoldAnimation()
        val start = holdProgress
        if (start <= 0f) {
            rippleDrawable.progress = 0f
            onEnd()
            return
        }
        reversing = true
        holdAnimator = ValueAnimator.ofFloat(start, 0f).apply {
            duration = frostReversibleRippleReverseDurationMs(appearance.fillDurationMs, start)
            interpolator = DecelerateInterpolator()
            addUpdateListener { updateHoldProgress(it.animatedValue as Float) }
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    reversing = false
                    holdProgress = 0f
                    rippleDrawable.progress = 0f
                    onEnd()
                }
            })
            start()
        }
    }

    private fun updateHoldProgress(progress: Float) {
        holdProgress = progress
        rippleDrawable.progress = progress
    }

    private fun finishHoldGesture(canceled: Boolean) {
        val shouldConfirm = commitReady && !canceled && !movedBeyondSlop
        gestureActive = false
        if (shouldConfirm) {
            playClickSound()
            listener.onConfirm()
            resetVisualsImmediately()
            movedBeyondSlop = false
            commitReady = false
            return
        }
        cancelHoldGesture {
            listener.onHoldCancel()
        }
    }

    private fun cancelHoldGesture(onFinished: (() -> Unit)? = null) {
        gestureActive = false
        commitReady = false
        cancelHoldAnimation()
        val finish: () -> Unit = {
            resetVisualsImmediately()
            movedBeyondSlop = false
            onFinished?.invoke()
        }
        if (holdProgress > 0f) {
            reverseHoldAnimation(finish)
        } else {
            finish()
        }
    }

    private fun resetVisualsImmediately() {
        cancelHoldAnimation()
        holdProgress = 0f
        rippleDrawable.progress = 0f
        animateHoldScale(armed = false)
    }

    private fun cancelHoldAnimation() {
        holdAnimator?.cancel()
        holdAnimator = null
    }

    private fun animateHoldScale(armed: Boolean) {
        if (!config.holdScaleEnabled) {
            target.animate().cancel()
            target.scaleX = 1f
            target.scaleY = 1f
            return
        }
        target.animate().cancel()
        val targetScale = if (armed) appearance.holdScale else 1f
        target.animate()
            .scaleX(targetScale)
            .scaleY(targetScale)
            .setDuration(appearance.scaleAnimationDurationMs.toLong())
            .setInterpolator(expandInterpolator)
            .start()
    }

    private fun movedBeyondSlop(x: Float, y: Float): Boolean =
        kotlin.math.abs(x - downX) > touchSlop || kotlin.math.abs(y - downY) > touchSlop

    private fun playClickSound() {
        if (clickSoundEnabled) {
            FrostUiClickSoundRegistry.playClick()
        }
    }
}
