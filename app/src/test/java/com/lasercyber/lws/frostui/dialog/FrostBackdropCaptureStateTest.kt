package com.lasercyber.lws.frostui.dialog

import org.junit.Assert.assertEquals
import org.junit.Test

class FrostBackdropCaptureStateTest {

    @Test
    fun policy_manualTakesPrecedenceOverIme() {
        assertEquals(
            FrostBackdropCapturePolicy.MANUAL,
            resolveFrostBackdropCapturePolicy(
                deferUntilIme = true,
                deferUntilManualCapture = true,
            ),
        )
    }

    @Test
    fun policy_mapsExistingDeferFlags() {
        assertEquals(
            FrostBackdropCapturePolicy.AFTER_IME_STABLE,
            resolveFrostBackdropCapturePolicy(
                deferUntilIme = true,
                deferUntilManualCapture = false,
            ),
        )
        assertEquals(
            FrostBackdropCapturePolicy.AUTO_AFTER_LAYOUT,
            resolveFrostBackdropCapturePolicy(
                deferUntilIme = false,
                deferUntilManualCapture = false,
            ),
        )
    }

    @Test
    fun state_requestDistinguishesInitialAndReplacementCapture() {
        assertEquals(
            FrostBackdropCaptureState.CAPTURING_INITIAL,
            FrostBackdropCaptureStateMachine.onRequest(hasFrame = false),
        )
        assertEquals(
            FrostBackdropCaptureState.CAPTURING_REPLACEMENT,
            FrostBackdropCaptureStateMachine.onRequest(hasFrame = true),
        )
    }

    @Test
    fun state_failedReplacementKeepsReadyWhileFailedInitialReturnsIdle() {
        assertEquals(
            FrostBackdropCaptureState.READY,
            FrostBackdropCaptureStateMachine.onComplete(success = false, hasFrame = true),
        )
        assertEquals(
            FrostBackdropCaptureState.IDLE,
            FrostBackdropCaptureStateMachine.onComplete(success = false, hasFrame = false),
        )
        assertEquals(
            FrostBackdropCaptureState.READY,
            FrostBackdropCaptureStateMachine.onComplete(success = true, hasFrame = true),
        )
    }

    @Test
    fun initialCapture_prefersLocalWhenCardIsReady() {
        assertEquals(
            FrostInitialCaptureDecision.CAPTURE_LOCAL,
            resolveInitialFrostBackdropCaptureDecision(
                cardReady = true,
                attempts = 0,
                maxAttempts = 30,
            ),
        )
    }

    @Test
    fun initialCapture_waitsForLayoutBeforeRetryLimit() {
        assertEquals(
            FrostInitialCaptureDecision.WAIT_FOR_LAYOUT,
            resolveInitialFrostBackdropCaptureDecision(
                cardReady = false,
                attempts = 29,
                maxAttempts = 30,
            ),
        )
    }

    @Test
    fun initialCapture_usesFullscreenFallbackAtRetryLimit() {
        assertEquals(
            FrostInitialCaptureDecision.CAPTURE_FULLSCREEN_FALLBACK,
            resolveInitialFrostBackdropCaptureDecision(
                cardReady = true,
                attempts = 30,
                maxAttempts = 30,
            ),
        )
    }

    @Test
    fun anchor_matchesScreenBounds_whenGeometryUnchanged() {
        val anchor = FrozenDialogAnchor(leftPx = 10, topPx = 20, widthPx = 300, heightPx = 200)
        assertEquals(true, anchor.matchesScreenBounds(anchor))
        assertEquals(
            false,
            anchor.matchesScreenBounds(
                FrozenDialogAnchor(leftPx = 11, topPx = 20, widthPx = 300, heightPx = 200),
            ),
        )
    }
}
