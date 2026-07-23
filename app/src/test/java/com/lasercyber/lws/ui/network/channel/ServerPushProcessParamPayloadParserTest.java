package com.lasercyber.lws.ui.network.channel;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;

import com.google.gson.JsonObject;
import com.lasercyber.lws.ui.bean.push.ProcessParametersPushEnvelope;

import org.junit.Test;

public class ServerPushProcessParamPayloadParserTest {

    @Test
    public void parse_legacy_envelope_payload_with_data() {
        JsonObject data = new JsonObject();
        data.addProperty("laserPower", 42);
        JsonObject root = new JsonObject();
        root.add("data", data);
        root.addProperty("msgId", "mid-1");
        ProcessParametersPushEnvelope envelope = ServerPushProcessParamPayloadParser.parse(root);
        assertNotNull(envelope);
        assertNotNull(envelope.getData());
        assertEquals(Integer.valueOf(42), envelope.getData().getLaserPower());
    }

    @Test
    public void parse_bare_process_parameters_at_root() {
        JsonObject root = new JsonObject();
        root.addProperty("laserPower", 7);
        ProcessParametersPushEnvelope envelope = ServerPushProcessParamPayloadParser.parse(root);
        assertNotNull(envelope);
        assertNotNull(envelope.getData());
        assertEquals(Integer.valueOf(7), envelope.getData().getLaserPower());
    }

    @Test
    public void parse_null_payload_returns_null() {
        assertNull(ServerPushProcessParamPayloadParser.parse(null));
    }
}
