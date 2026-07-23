package com.lasercyber.lws.ui.common.utils;

import com.lasercyber.lws.ui.common.enums.UnitSystem;

/**
 * Formats cumulative wire consumption ({@code consumableTimeLength}, stored in mm) for UI display.
 */
public final class WireConsumptionDisplayUtil {

    /** Matches {@link InchMillimeterUtils}: 12 in/ft × 25 mm/in. */
    private static final double MM_PER_FOOT = 25d * 12d;

    private WireConsumptionDisplayUtil() {
    }

    public static DisplayValue format(long consumableLengthMm, String unitWireValue) {
        if (TemperatureUnitConvertUtil.isMetricUnit(unitWireValue)) {
            return new DisplayValue(String.valueOf(consumableLengthMm / 1000L), " m");
        }
        long feet = Math.round(consumableLengthMm / MM_PER_FOOT);
        return new DisplayValue(String.valueOf(feet), " ft");
    }

    public static DisplayValue format(Long consumableLengthMm, String unitWireValue) {
        long mm = consumableLengthMm != null ? consumableLengthMm : 0L;
        return format(mm, unitWireValue != null ? unitWireValue : UnitSystem.METRIC.getWireValue());
    }

    public static final class DisplayValue {
        private final String number;
        private final String unit;

        public DisplayValue(String number, String unit) {
            this.number = number;
            this.unit = unit;
        }

        public String getNumber() {
            return number;
        }

        public String getUnit() {
            return unit;
        }
    }
}
