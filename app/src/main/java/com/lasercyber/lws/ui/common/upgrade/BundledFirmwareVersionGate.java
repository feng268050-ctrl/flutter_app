package com.lasercyber.lws.ui.common.upgrade;

import com.lasercyber.lws.ui.common.utils.UpgradeFileReaderUtils;

import java.util.Objects;
import java.util.regex.Pattern;

/**
 * Pure version gating for APK-bundled control-card firmware filenames.
 */
public final class BundledFirmwareVersionGate {

    public static final String FIRMWARE_FILE_PATTERN = "LSW01H\\d{4}S\\d{4}\\.bin";
    private static final Pattern PATTERN = Pattern.compile(FIRMWARE_FILE_PATTERN, Pattern.CASE_INSENSITIVE);

    private BundledFirmwareVersionGate() {
    }

    public static boolean isValidFirmwareFileName(String fileName) {
        return fileName != null && PATTERN.matcher(fileName).matches();
    }

    /**
     * @return true when hardware matches and bundled software version is strictly greater.
     */
    public static boolean isUpgradeCandidate(String bundledFileName, Integer deviceHw, Integer deviceSw) {
        if (!isValidFirmwareFileName(bundledFileName)) {
            return false;
        }
        Integer bundledHw = UpgradeFileReaderUtils.getFileHardwareVersion(bundledFileName);
        Integer bundledSw = UpgradeFileReaderUtils.getFileSoftwareVersion(bundledFileName);
        if (bundledHw == null || bundledSw == null || deviceHw == null || deviceSw == null) {
            return false;
        }
        if (!Objects.equals(bundledHw, deviceHw)) {
            return false;
        }
        return bundledSw > deviceSw;
    }
}
