package com.lasercyber.lws.ui.common.config;

/**
 * C001 (controller ↔ tablet Modbus) fault detection strategy from ROM {@code control_card_comm_alarm_mode}.
 */
public enum ControlCardCommAlarmMode {
    /** ≥3 failures in the last 5 segment polls (default). */
    SLIDE_WINDOW("slide_window"),
    /** Alarm on the latest failed or truncated poll; clear on the next success. */
    IMMEDIATE("immediate");

    private final String propertyValue;

    ControlCardCommAlarmMode(String propertyValue) {
        this.propertyValue = propertyValue;
    }

    public String getPropertyValue() {
        return propertyValue;
    }
}
