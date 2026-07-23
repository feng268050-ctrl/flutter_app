package com.lasercyber.lws.ai.zeropoint;
/**
 * Maps native zero-point {@code offset_x} (pixels) to Advanced Settings UI units.
 * UI: 1 unit = 3px; + moves zero right; − moves zero left.
 */
public final class ZeroPointCorrectionMapper {

    public static final int MIN_UI = -30;
    public static final int MAX_UI = 30;
    public static final double PIXELS_PER_UI_UNIT = 3.0;
    /** |offset_x| ≤ this: skip 0090H write and offset alert. offset_y is informational only. */
    public static final double POSITION_TOLERANCE_PX = 16.0;

    private ZeroPointCorrectionMapper() {
    }

    /** Only {@code offset_x} vs reference is used for tolerance; {@code offset_y} is ignored. */
    public static boolean isWithinPositionTolerance(double offsetX, double offsetY) {
        return Math.abs(offsetX) <= POSITION_TOLERANCE_PX;
    }

    public static int uiDeltaFromOffsetPx(double offsetX) {
        return (int) Math.round(-offsetX / PIXELS_PER_UI_UNIT);
    }

    public static int applyDelta(int currentUi, int uiDelta) {
        return clamp(currentUi + uiDelta);
    }

    public static int clamp(int value) {
        return Math.max(MIN_UI, Math.min(MAX_UI, value));
    }
}
