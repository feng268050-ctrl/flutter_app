package com.lasercyber.lws.ui.common.version;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNull;

import org.junit.Test;

public class SemanticVersionHelperTest {

    @Test
    public void toCoreVersion_stripsVPrefixAndBetaPrerelease() {
        assertEquals("1.0.17", SemanticVersionHelper.toCoreVersion("v1.0.17-beta"));
    }

    @Test
    public void toCoreVersion_stripsAlphaPrerelease() {
        assertEquals("1.0.17", SemanticVersionHelper.toCoreVersion("v1.0.17-alpha"));
        assertEquals("1.0.17", SemanticVersionHelper.toCoreVersion("V1.0.17-alpha"));
    }

    @Test
    public void toCoreVersion_stripsBuildMetadata() {
        assertEquals("1.0.0", SemanticVersionHelper.toCoreVersion("1.0.0+build.1"));
    }

    @Test
    public void toCoreVersion_nullOrBlank() {
        assertNull(SemanticVersionHelper.toCoreVersion(null));
        assertNull(SemanticVersionHelper.toCoreVersion("  "));
    }

    @Test
    public void resolveOtaUpgradeTitle_usesManifestTitleWhenNonBlank() {
        assertEquals("Hotfix", SemanticVersionHelper.resolveOtaUpgradeTitle("Hotfix", "2.0.0-beta"));
    }

    @Test
    public void resolveOtaUpgradeTitle_fallsBackToCoreVersionWithoutPrerelease() {
        assertEquals("1.2.3", SemanticVersionHelper.resolveOtaUpgradeTitle(null, "v1.2.3-beta"));
        assertEquals("1.2.3", SemanticVersionHelper.resolveOtaUpgradeTitle("  ", "1.2.3-alpha"));
    }

    @Test
    public void resolveOtaUpgradeTitle_blankTitleAndNoVersion() {
        assertEquals("Upgrade", SemanticVersionHelper.resolveOtaUpgradeTitle(null, null));
        assertEquals("Upgrade", SemanticVersionHelper.resolveOtaUpgradeTitle("", "  "));
    }
}
