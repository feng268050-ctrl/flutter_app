package com.lasercyber.lws.ui.common.mdns;

import org.junit.Assert;
import org.junit.Test;

public class DeviceConnectionEndpointContractTest {

    @Test
    public void shouldFallbackToDefaultPortAndProtocol() {
        DeviceConnectionEndpointContract.Endpoint endpoint =
                DeviceConnectionEndpointContract.endpoint("192.168.1.8", 0, "invalid");
        Assert.assertEquals(DeviceMdnsContract.DEFAULT_CONNECT_PORT, endpoint.getPort());
        Assert.assertEquals(DeviceMdnsContract.CONNECT_PROTO_WS, endpoint.getProtocol());
    }

    @Test
    public void shouldExposeHandshakeDefaults() {
        DeviceConnectionEndpointContract.Endpoint endpoint =
                DeviceConnectionEndpointContract.endpoint("192.168.1.9", 9527, "ws");
        Assert.assertEquals(DeviceMdnsContract.HANDSHAKE_TIMEOUT_MS, endpoint.getHandshakeTimeoutMs());
        Assert.assertEquals(DeviceMdnsContract.RETRY_LIMIT, endpoint.getRetryLimit());
    }
}
