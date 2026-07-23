package com.lasercyber.lws.ai.stream;
import com.lasercyber.lws.ai.NativeBridge;
import com.lasercyber.lws.ai.model.AiStainDetectResult;
import com.lasercyber.lws.ai.model.OpencvStainDetectResult;
import com.lasercyber.lws.ai.model.StainDetectSource;
import com.lasercyber.lws.ai.stain.AiStainDetectResultMapper;
import com.lasercyber.lws.ai.stain.OpencvStainDetectResultMapper;
import com.lasercyber.lws.ai.zeropoint.ZeroPointDetectJson;

import org.junit.Assert;
import org.junit.Test;

/**
 * Maps native stream-detect bus payloads to existing Java result types.
 */
public final class StreamDetectBusMappingTest {

    @Test
    public void lensDetSummary_invalidTargetFile_mapsToFailure() {
        String summary = "{\"ok\":true,\"code\":0,\"reason\":\"\",\"files\":[\"/tmp/target.json\"]}";
        OpencvStainDetectResult result = OpencvStainDetectResultMapper.fromNativeSummary(
                summary,
                1920,
                1080,
                1_700_000_000_000L,
                StainDetectSource.LIVE);
        Assert.assertFalse(result.success);
    }

    @Test
    public void zeroPointSummary_parsesOffsetFields() {
        String json = "{\"ok\":true,\"code\":0,\"reason\":\"\",\"offset_x\":1.5,\"offset_y\":-2.0}";
        ZeroPointDetectJson.Sample sample = ZeroPointDetectJson.parse(json);
        Assert.assertTrue(sample.ok);
        Assert.assertEquals(1.5, sample.offsetX, 0.001);
        Assert.assertEquals(-2.0, sample.offsetY, 0.001);
    }

    @Test
    public void rknnStainOutcome_mapsToAiStainDetectResult() {
        NativeBridge.StainInferOutcome outcome = new NativeBridge.StainInferOutcome(
                0, "", "live_infer", 1, "MILD", "ok", 640, 480,
                new NativeBridge.StainBox[0], false, 0);
        AiStainDetectResult ai = AiStainDetectResultMapper.fromStainInferOutcome(
                outcome, 100L, StainDetectSource.LIVE);
        Assert.assertTrue(ai.success);
        Assert.assertEquals(1, ai.level);
        Assert.assertEquals("MILD", ai.status);
    }
}
