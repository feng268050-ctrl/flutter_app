package com.lasercyber.lws.ui.network.http.local;

import org.junit.Assert;
import org.junit.Test;

public class CameraLanHttpProxyPolicyTest {

    @Test
    public void shouldRun_stagingBuild_nonProdTier() {
        Assert.assertTrue(CameraLanHttpProxyPolicy.shouldRun(true, false));
    }

    @Test
    public void shouldRun_falseWhenReleaseChannelApk() {
        Assert.assertFalse(CameraLanHttpProxyPolicy.shouldRun(false, false));
    }

    @Test
    public void shouldRun_falseWhenEffectiveProdTier() {
        Assert.assertFalse(CameraLanHttpProxyPolicy.shouldRun(true, true));
    }
}
