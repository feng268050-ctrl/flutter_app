package com.lasercyber.lws.ui.common.upgrade;

import com.lasercyber.lws.ui.bean.entity.ControllerUpgradeDataCache;
import com.lasercyber.lws.ui.component.dialog.GlobalDialogUtil;

/**
 * Reports control-card firmware byte progress to bundled-dialog and/or OTA upgrade UI.
 */
public final class FirmwareUpgradeProgressReporter {

    public interface OtaListener {
        /** @param firmwareFilePercent 0–100 of the firmware file transferred */
        void onFirmwareFileProgress(int firmwareFilePercent);
    }

    private static volatile OtaListener otaListener;

    private FirmwareUpgradeProgressReporter() {
    }

    public static void setOtaListener(OtaListener listener) {
        otaListener = listener;
    }

    public static void reportPacketProgress(ControllerUpgradeDataCache cache, int offset, Integer length) {
        if (cache == null || cache.getFile() == null) {
            return;
        }
        long fileLength = cache.getFile().length();
        if (fileLength <= 0) {
            return;
        }
        int chunk = length != null ? length : 0;
        int filePercent = (int) Math.min(99, ((offset + (long) chunk) * 100L) / fileLength);
        if (FirmwareUpgradeCoordinator.isBundledUpgradeInProgress()) {
            GlobalDialogUtil.updateFirmwareUpgradeProgress(filePercent);
        }
        OtaListener listener = otaListener;
        if (FirmwareUpgradeCoordinator.isOtaUpgradeInProgress() && listener != null) {
            listener.onFirmwareFileProgress(filePercent);
        }
    }
}
