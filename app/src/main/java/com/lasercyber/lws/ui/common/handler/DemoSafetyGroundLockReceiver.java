package com.lasercyber.lws.ui.common.handler;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/**
 * Receives {@link DemoSafetyGroundLockTrigger#ACTION_DEMO_SAFETY_GROUND_LOCK} from adb broadcast.
 */
public final class DemoSafetyGroundLockReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null
                || !DemoSafetyGroundLockTrigger.ACTION_DEMO_SAFETY_GROUND_LOCK.equals(intent.getAction())) {
            return;
        }
        DemoSafetyGroundLockTrigger.handle(context);
    }
}
