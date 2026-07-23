package com.lasercyber.lws.ui.common.network.proxy;

import org.junit.Assert;
import org.junit.Test;

public class NetworkHttpClientProviderTest {

    @Test
    public void httpProxySettings_validWhenDisabled() {
        HttpProxySettings settings = HttpProxySettings.disabled();
        Assert.assertFalse(settings.shouldApplyProxy());
    }

    @Test
    public void httpProxySettings_invalidWhenEnabledWithoutHost() {
        HttpProxySettings settings = new HttpProxySettings(
                true, "", 8080, ProxyAuthType.NONE, "", "");
        Assert.assertFalse(settings.shouldApplyProxy());
    }
}
