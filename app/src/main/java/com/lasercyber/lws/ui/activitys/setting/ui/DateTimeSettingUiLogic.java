package com.lasercyber.lws.ui.activitys.setting.ui;

public final class DateTimeSettingUiLogic {
    private DateTimeSettingUiLogic() {}

    public static boolean isManualDateTimeEnabled(boolean automaticDateTime) {
        return !automaticDateTime;
    }

    public static boolean isManualTimeZoneEnabled(boolean automaticTimeZone) {
        return !automaticTimeZone;
    }
}
