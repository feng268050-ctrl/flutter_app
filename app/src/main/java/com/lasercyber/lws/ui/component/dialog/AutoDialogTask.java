package com.lasercyber.lws.ui.component.dialog;

import com.lasercyber.lws.ui.common.queue.SerialTask;

/** {@link SerialTask} for dialogs shown through {@link AutoDialogQueue}. */
public interface AutoDialogTask extends SerialTask {

    int PRIORITY_WIFI_INIT = 10;
    int PRIORITY_REMOTE_LOCK = 20;
    int PRIORITY_BUNDLED_FIRMWARE = 40;
    /** Remote single process-parameter received summary. */
    int PRIORITY_REMOTE_PROCESS_PARAM = 45;
    int PRIORITY_BIND_DEVICE = 50;
    int PRIORITY_FORCED_WS_DISCONNECT = 60;
    int PRIORITY_DEVICE_REGISTRATION = 65;
    /** Passive / polled alarm and warn dialogs — before home startup prompts. */
    int PRIORITY_PASSIVE_ALARM = 8;
    /** User-initiated blocking checks (e.g. before enabling laser). */
    int PRIORITY_IMMEDIATE_ALARM = 5;
}
