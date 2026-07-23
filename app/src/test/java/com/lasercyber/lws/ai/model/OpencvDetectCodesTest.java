package com.lasercyber.lws.ai.model;
import com.lasercyber.lws.ai.model.OpencvDetectCodes;
import com.lasercyber.lws.ai.model.OpencvStainDetectJson;
import com.lasercyber.lws.ai.zeropoint.ZeroPointDetectJson;

import org.junit.Assert;
import org.junit.Test;

public class OpencvDetectCodesTest {

    @Test
    public void fromCode_mapsUnifiedValues() {
        Assert.assertEquals(OpencvDetectCodes.FRAME_REJECTED, OpencvDetectCodes.fromCode(-5));
        Assert.assertEquals(OpencvDetectCodes.CONFIG_ERROR, OpencvDetectCodes.fromCode(-6));
    }

    @Test
    public void zeroPointSpotSizeRejection_usesFrameRejectedAndReason() {
        String json = "{\"ok\":false,\"code\":-5,\"reason\":\"spot_size_above_max\","
                + "\"offset_x\":0,\"offset_y\":0}";
        ZeroPointDetectJson.Sample sample = ZeroPointDetectJson.parse(json);
        Assert.assertFalse(sample.ok);
        Assert.assertEquals(OpencvDetectCodes.FRAME_REJECTED, sample.detectCode());
        Assert.assertTrue(sample.isSpotSizeRejection());
        Assert.assertEquals(OpencvDetectCodes.REASON_SPOT_SIZE_ABOVE_MAX, sample.reason);
    }

    @Test
    public void lensDetSaturationRejection_usesFrameRejectedAndReason() {
        String json = "{\"ok\":false,\"code\":-5,\"reason\":\"saturated_white_area_exceeds_limit\","
                + "\"files\":[]}";
        OpencvStainDetectJson.Summary summary = OpencvStainDetectJson.parseSummary(json);
        Assert.assertFalse(summary.ok);
        OpencvDetectCodes code = OpencvDetectCodes.fromCode(summary.code);
        Assert.assertTrue(code.isSaturationRejection(summary.reason));
    }

    @Test
    public void redFrameGateRejection_usesFrameRejectedAndReason() {
        OpencvDetectCodes code = OpencvDetectCodes.fromCode(-5);
        Assert.assertTrue(code.isRedFrameGateRejection(OpencvDetectCodes.REASON_OVEREXPOSED));
        Assert.assertTrue(code.isRedFrameGateRejection(OpencvDetectCodes.REASON_INVALID_NON_RED));
        Assert.assertTrue(code.isSaturationRejection(OpencvDetectCodes.REASON_OVEREXPOSED));
    }

    @Test
    public void lensDetDetectFailed_parsesReasonToken() {
        String json = "{\"ok\":false,\"code\":-3,\"reason\":\"no_target_after_filter\",\"files\":[]}";
        OpencvStainDetectJson.Summary summary = OpencvStainDetectJson.parseSummary(json);
        Assert.assertEquals(OpencvDetectCodes.DETECT_FAILED, OpencvDetectCodes.fromCode(summary.code));
        Assert.assertEquals(OpencvDetectCodes.REASON_NO_TARGET_AFTER_FILTER, summary.reason);
    }
}
