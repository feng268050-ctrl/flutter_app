package com.lasercyber.lws.ui.common.upgrade;

/**
 * Serializes control-card firmware OTA between bundled-home-screen and {@code UpgradeActivity} paths.
 */
public final class FirmwareUpgradeCoordinator {

    private static volatile boolean bundledUpgradeInProgress;
    private static volatile boolean otaUpgradeInProgress;

    private FirmwareUpgradeCoordinator() {
    }

    public static boolean isBundledUpgradeInProgress() {
        return bundledUpgradeInProgress;
    }

    public static boolean isOtaUpgradeInProgress() {
        return otaUpgradeInProgress;
    }

    public static boolean isBusy() {
        return bundledUpgradeInProgress || otaUpgradeInProgress;
    }

    public static boolean canStartFirmwareUpgrade() {
        return !isBusy();
    }

    /**
     * Whether {@code UpgradeActivity} may start Modbus firmware transfer from an OTA ZIP {@code .bin}.
     * The OTA flow sets {@link #otaUpgradeInProgress} for the whole activity; that must not block this call.
     */
    public static boolean canStartOtaFirmwareTransfer() {
        return !bundledUpgradeInProgress;
    }

    public static void markBundledUpgradeStarted() {
        bundledUpgradeInProgress = true;
    }

    public static void markBundledUpgradeEnded() {
        bundledUpgradeInProgress = false;
    }

    public static void setOtaUpgradeInProgress(boolean inProgress) {
        otaUpgradeInProgress = inProgress;
    }
}
