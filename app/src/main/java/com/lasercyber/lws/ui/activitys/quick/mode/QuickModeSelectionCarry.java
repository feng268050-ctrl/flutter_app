package com.lasercyber.lws.ui.activitys.quick.mode;

import androidx.annotation.Nullable;

/**
 * Session-scoped Quick Mode selection carry: material, gear, thickness, and swing width.
 * Cleared when entering {@link QuickModeActivity}; not persisted to disk.
 *
 * <p>On process-mode switch, the newly shown page prefers these values so gear/thickness
 * inherit from the previous mode. Thickness/swing that cannot pair with the inherited gear
 * fall back to the first valid value for that gear (see {@link QuickModeSelectionResolver}).
 */
public final class QuickModeSelectionCarry {

    @Nullable
    private static volatile Integer materialType;
    @Nullable
    private static volatile Integer gear;
    @Nullable
    private static volatile Double thickness;
    @Nullable
    private static volatile Double swingWidth;

    private QuickModeSelectionCarry() {
    }

    public static void clear() {
        materialType = null;
        gear = null;
        thickness = null;
        swingWidth = null;
    }

    /**
     * Remembers non-null fields only so thickness and swing width stay independent across mode families.
     */
    public static void remember(
            @Nullable Integer material,
            @Nullable Integer gearValue,
            @Nullable Double thicknessValue,
            @Nullable Double swingWidthValue) {
        if (material != null) {
            materialType = material;
        }
        if (gearValue != null) {
            gear = gearValue;
        }
        if (thicknessValue != null) {
            thickness = thicknessValue;
        }
        if (swingWidthValue != null) {
            swingWidth = swingWidthValue;
        }
    }

    @Nullable
    public static Integer getMaterialType() {
        return materialType;
    }

    @Nullable
    public static Integer getGear() {
        return gear;
    }

    @Nullable
    public static Double getThickness() {
        return thickness;
    }

    @Nullable
    public static Double getSwingWidth() {
        return swingWidth;
    }
}
