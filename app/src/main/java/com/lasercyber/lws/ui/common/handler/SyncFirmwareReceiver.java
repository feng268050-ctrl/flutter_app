package com.lasercyber.lws.ui.common.handler;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

import com.lasercyber.lws.ui.common.upgrade.SyncFirmwareTrigger;

/**
 * Receives {@link SyncFirmwareTrigger#ACTION_SYNC_FIRMWARE} from {@code make sync-firmware}.
 */
public final class SyncFirmwareReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null || !SyncFirmwareTrigger.ACTION_SYNC_FIRMWARE.equals(intent.getAction())) {
            return;
        }
        SyncFirmwareTrigger.schedule(context, intent.getStringExtra(SyncFirmwareTrigger.EXTRA_FIRMWARE_PATH));
    }
}
