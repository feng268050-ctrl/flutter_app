package com.lasercyber.lws.ui.common.enums;

/**
 * Temperature / length display unit preference stored in {@code t_common_settings.unit}.
 */
public enum UnitSystem {
    IMPERIAL("imperial"),
    METRIC("metric");

    private final String wireValue;

    UnitSystem(String wireValue) {
        this.wireValue = wireValue;
    }

    public String getWireValue() {
        return wireValue;
    }

    public static UnitSystem fromWireValue(String value) {
        if (value == null) {
            return METRIC;
        }
        if (IMPERIAL.wireValue.equalsIgnoreCase(value)) {
            return IMPERIAL;
        }
        return METRIC;
    }

    /** Legacy {@code unitSetting}: {@code false} = imperial, {@code true}/null = metric. */
    public static UnitSystem fromLegacyUnitSetting(Boolean unitSetting) {
        return unitSetting != null && !unitSetting ? IMPERIAL : METRIC;
    }

    public Boolean toLegacyUnitSetting() {
        return this == METRIC;
    }
}
