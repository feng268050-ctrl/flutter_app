package com.lasercyber.lws.ui.network.mediamtx;

import com.lasercyber.lws.ui.common.version.SemanticVersionHelper;

import org.junit.Assert;
import org.junit.Test;

public class MediaMtxBinaryVersionTest {

    @Test
    public void versionFromOtaFileName_parsesSemverSegment() {
        Assert.assertEquals("1.11.4",
                MediaMtxBinary.versionFromOtaFileName("mediamtx_v1.11.4-arm64.zip"));
    }

    @Test
    public void isCandidateNewer_whenInstalledOlder() {
        Assert.assertTrue(MediaMtxBinary.isCandidateNewer("1.11.3", "1.11.4"));
        Assert.assertFalse(MediaMtxBinary.isCandidateNewer("1.11.4", "1.11.3"));
    }

    @Test
    public void semver_androidPrerelease_isNotNewerThanPlainPatch() {
        // Documents why we force-replace legacy linux cache (see isLegacyLinuxInstall).
        Assert.assertTrue(SemanticVersionHelper.compare("v1.11.3", "v1.11.3-android") > 0);
    }
}
