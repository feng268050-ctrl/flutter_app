package com.lasercyber.lws.ui.common.handler;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/**
 * Receives {@link DemoAlarmTrigger#ACTION_DEMO_ALARM} from {@code make alarm} (adb broadcast).
 */
public final class DemoAlarmReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null) {
            return;
        }
        String action = intent.getAction();
        if (DemoAlarmTrigger.ACTION_DEMO_ALARM_CLEAN.equals(action)) {
            DemoAlarmTrigger.clean(context);
            return;
        }
        if (!DemoAlarmTrigger.ACTION_DEMO_ALARM.equals(action)) {
            return;
        }
        DemoAlarmTrigger.handle(context, intent.getStringExtra(DemoAlarmTrigger.EXTRA_CODE));
    }
}
