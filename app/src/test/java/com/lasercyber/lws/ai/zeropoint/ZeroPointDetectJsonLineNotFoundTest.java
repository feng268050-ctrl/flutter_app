package com.lasercyber.lws.ai.zeropoint;
import com.lasercyber.lws.ai.model.OpencvDetectCodes;
import com.lasercyber.lws.ai.zeropoint.ZeroPointDetectJson;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;

import org.junit.Test;

public class ZeroPointDetectJsonLineNotFoundTest {

    @Test
    public void parsesLineNotFoundFailure() {
        ZeroPointDetectJson.Sample sample = ZeroPointDetectJson.parse(
                "{\"ok\":false,\"code\":-3,\"reason\":\"line_not_found\",\"offset_x\":0,\"offset_y\":0}");
        assertFalse(sample.ok);
        assertEquals(OpencvDetectCodes.DETECT_FAILED.code(), sample.code);
        assertEquals(OpencvDetectCodes.REASON_LINE_NOT_FOUND, sample.reason);
    }
}
