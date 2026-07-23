package com.lasercyber.lws.ui.network.channel;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNull;

import org.junit.Test;

public class DeviceChannelCoreTest {

    @Test
    public void should_validate_data_event_required_fields() {
        DeviceDataEvent event = new DeviceDataEvent()
                .setCorrelationId("cid-1")
                .setPayload("{\"k\":\"v\"}")
                .setTimestamp(System.currentTimeMillis())
                .setSourceProtocol(DeviceChannelProtocol.WS);
        assertNull(DeviceChannelValidator.validate(event));
    }

    @Test
    public void should_reject_missing_command_topic() {
        DeviceCommandRequest request = new DeviceCommandRequest()
                .setCorrelationId("cid-2")
                .setPayload("{}");
        assertEquals("missing_target_topic", DeviceChannelValidator.validate(request));
    }

    @Test
    public void should_transition_to_timeout_when_overdue() {
        String correlationId = "cid-timeout";
        DeviceCommandLifecycleTracker.markDispatched(correlationId);
        DeviceCommandLifecycleTracker.markTimeoutIfNeeded(correlationId, 0);
        assertEquals(CommandDispatchStatus.TIMEOUT, DeviceCommandLifecycleTracker.getStatus(correlationId));
    }
}
