package com.lasercyber.lws.ui.common.upgrade;

import com.lasercyber.lws.ui.common.utils.UpgradeFileReaderUtils;

import org.junit.Assert;
import org.junit.Test;

public class BundledFirmwareVersionGateTest {

    @Test
    public void validFirmwareFileName_matchesPattern() {
        Assert.assertTrue(BundledFirmwareVersionGate.isValidFirmwareFileName("LSW01H1000S1013.bin"));
        Assert.assertFalse(BundledFirmwareVersionGate.isValidFirmwareFileName("LSW01H1000S1013.BIN.extra"));
    }

    @Test
    public void isUpgradeCandidate_whenSoftwareNewerAndHardwareMatches() {
        Assert.assertTrue(BundledFirmwareVersionGate.isUpgradeCandidate(
                "LSW01H1000S1013.bin", 1000, 1012));
    }

    @Test
    public void isUpgradeCandidate_falseWhenSameSoftware() {
        Assert.assertFalse(BundledFirmwareVersionGate.isUpgradeCandidate(
                "LSW01H1000S1012.bin", 1000, 1012));
    }

    @Test
    public void isUpgradeCandidate_falseWhenHardwareMismatch() {
        Assert.assertFalse(BundledFirmwareVersionGate.isUpgradeCandidate(
                "LSW01H1001S1013.bin", 1000, 1012));
    }

    @Test
    public void isUpgradeCandidate_falseWhenSoftwareOlder() {
        Assert.assertFalse(BundledFirmwareVersionGate.isUpgradeCandidate(
                "LSW01H1000S1010.bin", 1000, 1012));
    }

    @Test
    public void upgradeFileReaderUtils_invalidName_returnsNullNotThrow() {
        Assert.assertNull(UpgradeFileReaderUtils.getFileHardwareVersion("bundled-firmware-import.bin"));
        Assert.assertNull(UpgradeFileReaderUtils.getFileSoftwareVersion("bundled-firmware-import.bin"));
    }
}
