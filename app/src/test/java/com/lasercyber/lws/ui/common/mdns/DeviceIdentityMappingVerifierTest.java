package com.lasercyber.lws.ui.common.mdns;

import org.junit.Assert;
import org.junit.Test;

public class DeviceIdentityMappingVerifierTest {

    @Test
    public void shouldMatchIgnoringCaseAndWhitespace() {
        Assert.assertTrue(DeviceIdentityMappingVerifier.isCanonicalIdentityMatch(
                "  LCYB-001  ",
                "lcyb-001"
        ));
    }

    @Test
    public void shouldNotMatchDifferentIdentity() {
        Assert.assertFalse(DeviceIdentityMappingVerifier.isCanonicalIdentityMatch(
                "LCYB-001",
                "LCYB-002"
        ));
    }
}
