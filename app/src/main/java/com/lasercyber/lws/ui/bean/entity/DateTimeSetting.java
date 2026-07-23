package com.lasercyber.lws.ui.bean.entity;

import lombok.Data;

@Data
public class DateTimeSetting {
    private boolean automaticDateTime;
    private boolean automaticTimeZone;
    private String dateValue;
    private String timeValue;
    private String timeZoneValue;
    private String autoSyncStatus;
}
