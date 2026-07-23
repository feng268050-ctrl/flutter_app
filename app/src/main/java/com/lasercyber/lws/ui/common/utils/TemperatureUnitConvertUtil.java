package com.lasercyber.lws.ui.common.utils;

import com.lasercyber.lws.ui.common.enums.UnitSystem;

import java.util.Locale;

/**
 * Advanced Settings temperature display conversion.
 * Stored values and device registers remain in Celsius; UI shows Fahrenheit when imperial is selected.
 */
public final class TemperatureUnitConvertUtil {

    private TemperatureUnitConvertUtil() {
    }

    /**
     * @param unitSetting {@code true} or {@code null} = metric / Celsius; {@code false} = imperial / Fahrenheit
     */
    public static boolean isMetricUnit(Boolean unitSetting) {
        return unitSetting == null || unitSetting;
    }

    public static boolean isMetricUnit(String unitWireValue) {
        return UnitSystem.fromWireValue(unitWireValue) == UnitSystem.METRIC;
    }

    public static int celsiusToFahrenheit(int celsius) {
        return Math.round(celsius * 9f / 5f + 32);
    }

    public static double celsiusToFahrenheit(double celsius) {
        return celsius * 9d / 5d + 32d;
    }

    public static int fahrenheitToCelsius(int fahrenheit) {
        return Math.round((fahrenheit - 32) * 5f / 9f);
    }

    public static String toDisplay(int celsius, Boolean unitSetting) {
        if (isMetricUnit(unitSetting)) {
            return String.valueOf(celsius);
        }
        return String.valueOf(celsiusToFahrenheit(celsius));
    }

    public static String formatScaleLabel(int celsius, Boolean unitSetting, String celsiusUnit, String fahrenheitUnit) {
        if (isMetricUnit(unitSetting)) {
            return celsius + celsiusUnit;
        }
        return celsiusToFahrenheit(celsius) + fahrenheitUnit;
    }

    /**
     * Converts user input in the current display unit to a Celsius value string for persistence.
     */
    public static String parseInputToCelsiusString(String input, Boolean unitSetting) {
        int value = Integer.parseInt(input.trim());
        if (isMetricUnit(unitSetting)) {
            return String.valueOf(value);
        }
        return String.valueOf(fahrenheitToCelsius(value));
    }

    /**
     * Formats a Celsius sensor value for on-screen display with unit suffix (one decimal).
     */
    public static String formatSensorCelsius(double celsius, String unitWireValue) {
        if (isMetricUnit(unitWireValue)) {
            return String.format(Locale.ENGLISH, "%.1f ℃", celsius);
        }
        return String.format(Locale.ENGLISH, "%.1f °F", celsiusToFahrenheit(celsius));
    }

    public static String invalidTemperaturePlaceholder(String unitWireValue) {
        return isMetricUnit(unitWireValue) ? "- ℃" : "- °F";
    }

    public static String formatIntegerCelsius(int celsius, String unitWireValue) {
        if (isMetricUnit(unitWireValue)) {
            return celsius + " ℃";
        }
        return Math.round(celsiusToFahrenheit(celsius)) + " °F";
    }
}
