package com.lasercyber.lws.ai.zeropoint;
import com.lasercyber.lws.ai.model.OpencvDetectCodes;
import com.lasercyber.lws.ai.zeropoint.ZeroPointDetectJson;

import org.junit.Assert;
import org.junit.Test;

public class ZeroPointDetectJsonTest {

    @Test
    public void parse_spotSizeRejectedFailure() {
        String json = "{\"ok\":false,\"code\":-5,\"reason\":\"spot_size_above_max\","
                + "\"offset_x\":0,\"offset_y\":0}";
        ZeroPointDetectJson.Sample sample = ZeroPointDetectJson.parse(json);
        Assert.assertFalse(sample.ok);
        Assert.assertEquals(OpencvDetectCodes.FRAME_REJECTED.code(), sample.code);
        Assert.assertEquals(ZeroPointDetectJson.REASON_SPOT_SIZE_ABOVE_MAX, sample.reason);
        Assert.assertTrue(sample.isSpotSizeRejection());
        Assert.assertEquals(0.0, sample.offsetX, 0.001);
    }

    @Test
    public void parse_successUnchanged() {
        String json = "{\"ok\":true,\"code\":0,\"offset_x\":-9.0,\"offset_y\":0.0}";
        ZeroPointDetectJson.Sample sample = ZeroPointDetectJson.parse(json);
        Assert.assertTrue(sample.ok);
        Assert.assertEquals(0, sample.code);
        Assert.assertEquals(-9.0, sample.offsetX, 0.001);
    }
}
