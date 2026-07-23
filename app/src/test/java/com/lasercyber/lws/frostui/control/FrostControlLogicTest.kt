package com.lasercyber.lws.frostui.control

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.hypot

class FrostControlLogicTest {

    @Test
    fun zeroLabelVisibleWhenRangeSpansZero() {
        assertTrue(shouldShowFrostSliderZeroLabel(-30, 30))
        assertTrue(shouldShowFrostSliderZeroLabel(-1, 10))
        assertFalse(shouldShowFrostSliderZeroLabel(0, 100))
        assertFalse(shouldShowFrostSliderZeroLabel(-10, 0))
        assertFalse(shouldShowFrostSliderZeroLabel(10, 20))
    }

    @Test
    fun checkedStateTransitionNotifiesOnlyOnChange() {
        assertFalse(shouldNotifyCheckedChange(wasChecked = true, requested = true))
        assertFalse(shouldNotifyCheckedChange(wasChecked = false, requested = false))
        assertTrue(shouldNotifyCheckedChange(wasChecked = false, requested = true))
        assertTrue(shouldNotifyCheckedChange(wasChecked = true, requested = false))
    }

    @Test
    fun defaultAnimationDurationIs200ms() {
        assertEquals(200, FrostControlDefaults.ANIMATION_DURATION_MS)
    }

    @Test
    fun switchEdgeSnapThreshold() {
        assertFalse(switchEdgeChecked(0.49f))
        assertTrue(switchEdgeChecked(0.5f))
        assertEquals(0f, switchEdgePosition(false), 0.01f)
        assertEquals(1f, switchEdgePosition(true), 0.01f)
    }

    @Test
    fun sliderFractionMapsThumbCenterToTravel() {
        assertEquals(0f, frostSliderFractionFromX(x = 16.5f, trackWidthPx = 200f, thumbSizePx = 33f), 0.01f)
        assertEquals(0.5f, frostSliderFractionFromX(x = 100f, trackWidthPx = 200f, thumbSizePx = 33f), 0.01f)
        assertEquals(1f, frostSliderFractionFromX(x = 183.5f, trackWidthPx = 200f, thumbSizePx = 33f), 0.01f)
    }

    @Test
    fun sliderFractionRespectsTrackStartInset() {
        val trackStartX = 5f
        val centerX = trackStartX + frostSliderThumbCenterX(0.5f, 200f, 33f)
        assertEquals(0.5f, frostSliderFractionFromX(centerX, 200f, 33f, trackStartX), 0.01f)
    }

    @Test
    fun sliderThumbDragOverflowCoversScaledRadiusGrowth() {
        val thumbRadiusPx = 16.5f
        val dragScale = 1.3f
        val overflow = frostSliderResolvedThumbDragOverflowPx(thumbRadiusPx, dragScale, dimenOverflowPx = 0f)
        assertEquals(thumbRadiusPx * 0.3f, overflow, 0.01f)
        assertTrue(overflow >= thumbRadiusPx * (dragScale - 1f))
    }

    @Test
    fun decelerateEasingEndsAtOne() {
        val easing = decelerateEasing()
        assertEquals(0f, easing.transform(0f), 0.01f)
        assertEquals(1f, easing.transform(1f), 0.01f)
    }

    @Test
    fun sliderProgressFromFractionClampsToRange() {
        assertEquals(-30, frostSliderProgressFromFraction(0f, -30, 30))
        assertEquals(30, frostSliderProgressFromFraction(1f, -30, 30))
        assertEquals(0, frostSliderProgressFromFraction(0.5f, -30, 30))
    }

    @Test
    fun sliderThumbCenterXMatchesFractionFromX() {
        val trackWidthPx = 200f
        val thumbSizePx = 33f
        val fraction = 0.5f
        val centerX = frostSliderThumbCenterX(fraction, trackWidthPx, thumbSizePx)
        assertEquals(fraction, frostSliderFractionFromX(centerX, trackWidthPx, thumbSizePx), 0.01f)
    }

    @Test
    fun sliderThumbHitRectAcceptsCenterRejectsTrackFarAway() {
        val hitRect = frostSliderThumbHitRect(
            thumbCenterX = 100f,
            touchHeightPx = 33f,
            thumbRadiusPx = 16.5f,
            minTouchHalfExtentPx = 16.5f,
        )
        assertTrue(frostSliderThumbHitRectContains(100f, 16.5f, hitRect))
        assertFalse(frostSliderThumbHitRectContains(10f, 16.5f, hitRect))
    }

    @Test
    fun capsuleThumbCenterXAndFractionAreInverse() {
        val outerWidthPx = 400f
        val insetPx = 5f
        val thumbSizePx = 33f
        val fraction = 0.75f
        val centerX = frostCapsuleThumbCenterX(fraction, outerWidthPx, insetPx, thumbSizePx)
        assertEquals(
            fraction,
            frostCapsuleSliderFractionFromX(centerX, outerWidthPx, insetPx, thumbSizePx),
            0.01f,
        )
    }

    @Test
    fun capsuleThumbHitRectUsesFillEdgeCenter() {
        val outerWidthPx = 400f
        val insetPx = 5f
        val thumbSizePx = 33f
        val centerX = frostCapsuleThumbCenterX(0.5f, outerWidthPx, insetPx, thumbSizePx)
        val hitRect = frostSliderThumbHitRect(
            thumbCenterX = centerX,
            touchHeightPx = 46f,
            thumbRadiusPx = thumbSizePx / 2f,
        )
        assertTrue(frostSliderThumbHitRectContains(centerX, 23f, hitRect))
        assertFalse(frostSliderThumbHitRectContains(insetPx + 10f, 23f, hitRect))
    }

    @Test
    fun sliderLongPressDefaultsMatchSpec() {
        assertEquals(200, FrostControlDefaults.SLIDER_LONG_PRESS_THRESHOLD_MS)
        assertEquals(200, FrostControlDefaults.SEGMENT_LONG_PRESS_THRESHOLD_MS)
        assertEquals(1.3f, FrostControlDefaults.SLIDER_THUMB_DRAG_SCALE, 0.01f)
    }

    @Test
    fun sliderValueUpdateRequiresValueArmedState() {
        var applied = false
        frostSliderApplyValueWhileArmed(isValueArmed = false) { applied = true }
        assertFalse(applied)
        frostSliderApplyValueWhileArmed(isValueArmed = true) { applied = true }
        assertTrue(applied)
    }

    @Test
    fun sliderFractionFromDeltaUsesRestingFractionAndActivationOffset() {
        val restingFraction = 0.5f
        val travelPx = 167f
        val activationX = 100f
        assertEquals(
            0.5f,
            frostSliderFractionFromDelta(restingFraction, activationX, activationX, travelPx),
            0.01f,
        )
        assertEquals(
            0.6f,
            frostSliderFractionFromDelta(restingFraction, activationX, activationX + travelPx * 0.1f, travelPx),
            0.01f,
        )
        assertEquals(0f, frostSliderFractionFromDelta(0.1f, 50f, -1000f, travelPx), 0.01f)
        assertEquals(1f, frostSliderFractionFromDelta(0.9f, 50f, 10000f, travelPx), 0.01f)
    }

    @Test
    fun centerSnapConfigOnlyWhenRangeSpansCenter() {
        val config = frostSliderCenterSnapConfig(
            min = -30,
            max = 30,
            centerValue = 0,
            threshold = 3,
            escapeDistancePx = 12f,
            dwellMs = 250L,
        )
        assertEquals(0.5f, config!!.centerFraction, 0.01f)
        assertNull(frostSliderCenterSnapConfig(0, 100, 0, 3, 12f, 250L))
    }

    @Test
    fun centerSnapEntersWhenValueWithinThreshold() {
        val config = frostSliderCenterSnapConfig(-30, 30, 0, 3, 12f, 100L)!!
        val session = FrostSliderCenterSnapSession().apply { dragRestingFraction = 0.48f }
        val result = frostSliderResolveDragValue(
            snapConfig = config,
            snapSession = session,
            min = -30,
            max = 30,
            travelPx = 167f,
            activationX = 100f,
            currentX = 102f,
            nowMs = 1_000L,
        )
        assertTrue(result.isCenterSnapped)
        assertTrue(result.enteredCenterSnap)
        assertEquals(0, result.value)
        assertEquals(0.5f, result.fraction, 0.01f)
    }

    @Test
    fun centerSnapHoldsWithinEscapeDistanceAndEscapesImmediately() {
        val config = frostSliderCenterSnapConfig(-30, 30, 0, 3, 12f, 100L)!!
        val session = FrostSliderCenterSnapSession().apply {
            dragRestingFraction = 0.5f
            isCenterSnapped = true
            snapAnchorX = 100f
            snapEnteredAtMs = 1_000L
        }
        val withinEscape = frostSliderResolveDragValue(
            config, session, -30, 30, 167f, 80f, 111f, 1_050L,
        )
        assertTrue(withinEscape.isCenterSnapped)
        assertEquals(0, withinEscape.value)

        val escapedDuringFeedback = frostSliderResolveDragValue(
            config, session, -30, 30, 167f, 80f, 113f, 1_050L,
        )
        assertFalse(escapedDuringFeedback.isCenterSnapped)
        assertEquals(113f, escapedDuringFeedback.reanchorActivationX!!, 0.01f)
        assertTrue(session.centerSnapSuppressed)
    }

    @Test
    fun centerSnapDoesNotReenterImmediatelyAfterEscape() {
        val config = frostSliderCenterSnapConfig(-30, 30, 0, 3, 12f, 100L)!!
        val session = FrostSliderCenterSnapSession().apply {
            dragRestingFraction = 0.5f
            isCenterSnapped = true
            snapAnchorX = 100f
            snapEnteredAtMs = 1_000L
        }
        val escaped = frostSliderResolveDragValue(
            config, session, -30, 30, 167f, 80f, 120f, 1_300L,
        )
        assertFalse(escaped.isCenterSnapped)
        assertTrue(session.centerSnapSuppressed)

        val continued = frostSliderResolveDragValue(
            config, session, -30, 30, 167f, 120f, 125f, 1_301L,
        )
        assertFalse(continued.isCenterSnapped)
        assertTrue(continued.value != 0 || continued.fraction != 0.5f)
    }

    @Test
    fun capsuleOverlayDarkFractionTransitionsAcrossCenter() {
        assertEquals(0f, frostCapsuleOverlayDarkFraction(10f, 50f, 20f), 0.01f)
        assertEquals(0.5f, frostCapsuleOverlayDarkFraction(50f, 50f, 20f), 0.01f)
        assertEquals(1f, frostCapsuleOverlayDarkFraction(90f, 50f, 20f), 0.01f)
    }

    @Test
    fun capsuleOverlayIconCenterUsesInnerTrackOrigin() {
        val innerTrackWidthPx = 390f
        val iconSizePx = 50f
        val iconCenterInnerPx = innerTrackWidthPx - iconSizePx / 2f
        val fillWidthPx = iconCenterInnerPx
        val darkWhenInnerCoords = frostCapsuleOverlayDarkFraction(
            fillWidthPx,
            iconCenterInnerPx,
            iconSizePx,
        )
        val darkWhenOuterCoords = frostCapsuleOverlayDarkFraction(
            fillWidthPx,
            iconCenterInnerPx + 5f,
            iconSizePx,
        )
        assertEquals(0.5f, darkWhenInnerCoords, 0.01f)
        assertTrue(darkWhenInnerCoords > darkWhenOuterCoords)
    }

    @Test
    fun numericStepIncrementsAndClampsDecimal() {
        val step = FrostNumericStepperLogic.METRIC_DECIMAL_STEP
        assertEquals(
            "0.2",
            FrostNumericStepperLogic.applyStep("0.1", true, true, step, 0, 100),
        )
        assertEquals(
            "0",
            FrostNumericStepperLogic.applyStep("0", false, true, step, 0, 100),
        )
        assertEquals(
            "100",
            FrostNumericStepperLogic.applyStep("99.95", true, true, step, 0, 100),
        )
    }

    @Test
    fun numericStepIncrementsInteger() {
        val step = FrostNumericStepperLogic.METRIC_DECIMAL_STEP
        assertEquals("2", FrostNumericStepperLogic.applyStep("1", true, false, step, 0, 10))
        assertEquals("0", FrostNumericStepperLogic.applyStep("1", false, false, step, 0, 10))
    }

    @Test
    fun formatDefaultInputStripsTrailingZero() {
        assertEquals("5", FrostNumericStepperLogic.formatDefaultInput("5.0", android.text.InputType.TYPE_CLASS_NUMBER))
        assertEquals("", FrostNumericStepperLogic.formatDefaultInput("", android.text.InputType.TYPE_CLASS_NUMBER))
    }

    @Test
    fun segmentPillOffsetCentersPillUnderFinger() {
        assertEquals(0f, frostSegmentPillOffsetPxFromX(50f, 100f, 400f), 0.01f)
        assertEquals(100f, frostSegmentPillOffsetPxFromX(150f, 100f, 400f), 0.01f)
        assertEquals(300f, frostSegmentPillOffsetPxFromX(500f, 100f, 400f), 0.01f)
    }

    @Test
    fun segmentIndexAtXMapsTrackPosition() {
        assertEquals(0, frostSegmentIndexAtX(50f, 100f, 4))
        assertEquals(1, frostSegmentIndexAtX(150f, 100f, 4))
        assertEquals(3, frostSegmentIndexAtX(350f, 100f, 4))
    }

    @Test
    fun segmentNearestIndexFromPillOffset() {
        assertEquals(0, frostSegmentNearestIndex(10f, 100f, 4))
        assertEquals(1, frostSegmentNearestIndex(110f, 100f, 4))
        assertEquals(3, frostSegmentNearestIndex(300f, 100f, 4))
    }

    @Test
    fun segmentSelectedHitRectCoversActiveCellOnly() {
        val rect = frostSegmentSelectedHitRect(
            selectedIndex = 1,
            segmentWidthPx = 100f,
            trackHeightPx = 48f,
        )
        assertTrue(frostSegmentSelectedHitRectContains(150f, 24f, rect))
        assertFalse(frostSegmentSelectedHitRectContains(50f, 24f, rect))
    }

    @Test
    fun segmentPreviewOffsetFollowsFingerDelta() {
        val offset = frostSegmentPreviewOffsetPx(
            restingOffsetPx = 100f,
            activationX = 150f,
            currentX = 200f,
            segmentWidthPx = 100f,
            trackWidthPx = 400f,
        )
        assertEquals(150f, offset, 0.01f)
    }

    @Test
    fun segmentPreviewOffsetClampsToTrackEnds() {
        assertEquals(0f, frostSegmentPreviewOffsetPx(0f, 50f, 0f, 100f, 400f), 0.01f)
        assertEquals(300f, frostSegmentPreviewOffsetPx(300f, 350f, 500f, 100f, 400f), 0.01f)
    }

    @Test
    fun segmentCancelBeforeLongPressUsesTouchSlop() {
        assertFalse(frostSegmentShouldCancelBeforeLongPress(10f, 16f))
        assertTrue(frostSegmentShouldCancelBeforeLongPress(20f, 16f))
    }

    @Test
    fun segmentRestingOffsetMatchesSelectedIndex() {
        assertEquals(200f, frostSegmentRestingOffsetPx(2, 100f), 0.01f)
    }

    @Test
    fun reversibleRippleCoverRadiusUsesFarthestCorner() {
        val radius = frostReversibleRippleCoverRadius(
            boundsLeft = 0f,
            boundsTop = 0f,
            boundsRight = 100f,
            boundsBottom = 50f,
            originX = 20f,
            originY = 10f,
        )
        assertEquals(hypot(80.0, 40.0).toFloat(), radius, 0.01f)
    }

    @Test
    fun reversibleRippleReverseDurationScalesWithProgress() {
        assertEquals(150L, frostReversibleRippleReverseDurationMs(300L, 0.5f))
        assertEquals(1L, frostReversibleRippleReverseDurationMs(300L, 0f))
    }
}
