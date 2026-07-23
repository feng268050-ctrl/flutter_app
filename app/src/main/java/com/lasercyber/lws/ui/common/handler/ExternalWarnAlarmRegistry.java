package com.lasercyber.lws.ui.common.handler;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Lookup for non-Modbus warn sources ({@link ExternalWarnAlarm}). Episode UI state in
 * {@link com.lasercyber.lws.ui.component.dialog.episode.WarnEpisodeController} tracks popup
 * lifecycle; {@link ExternalWarnAlarm#isFaultActive()} is the source of truth for whether the
 * underlying fault persists.
 */
public final class ExternalWarnAlarmRegistry {

    private static final Map<String, ExternalWarnAlarm> BY_CODE = new LinkedHashMap<>();

    static {
        register(CameraCommunicationWarnAlarm.INSTANCE);
    }

    private ExternalWarnAlarmRegistry() {
    }

    @Nullable
    public static ExternalWarnAlarm forCode(@Nullable String alarmCode) {
        if (alarmCode == null || alarmCode.isEmpty()) {
            return null;
        }
        return BY_CODE.get(alarmCode);
    }

  @VisibleForTesting
    static void register(@NonNull ExternalWarnAlarm alarm) {
        BY_CODE.put(alarm.getAlarmCode(), alarm);
    }

    @VisibleForTesting
    static void resetForTest() {
        BY_CODE.clear();
        register(CameraCommunicationWarnAlarm.INSTANCE);
    }
}
