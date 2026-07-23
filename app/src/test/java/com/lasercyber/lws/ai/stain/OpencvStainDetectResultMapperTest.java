package com.lasercyber.lws.ai.stain;
import com.lasercyber.lws.ai.model.OpencvStainDetectJson;
import com.lasercyber.lws.ai.model.OpencvStainDetectResult;
import com.lasercyber.lws.ai.model.StainDetectSource;
import com.lasercyber.lws.ai.stain.OpencvStainDetectResultMapper;
import com.lasercyber.lws.ui.common.ai.overlay.DetectionOverlayMapper;

import org.junit.Assert;
import org.junit.Test;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;

public class OpencvStainDetectResultMapperTest {

    @Test
    public void fromNativeSummary_readsTargetFile() throws Exception {
        File dir = Files.createTempDirectory("lens_det_test").toFile();
        File target = new File(dir, "target.json");
        Files.write(target.toPath(),
                ("{\"name\":\"target\",\"x\":923.4,\"y\":563.2,"
                        + "\"bbox_x\":900,\"bbox_y\":540,\"w\":79,\"h\":67}")
                        .getBytes(StandardCharsets.UTF_8));

        String summary = "{\"ok\":true,\"code\":0,\"files\":[\"" + target.getAbsolutePath() + "\"]}";
        OpencvStainDetectResult result = OpencvStainDetectResultMapper.fromNativeSummary(
                summary, 1920, 1080, 100L, StainDetectSource.LIVE);

        Assert.assertTrue(result.success);
        Assert.assertEquals(923.4, result.targetX, 0.01);
        Assert.assertEquals(563.2, result.targetY, 0.01);
        Assert.assertEquals(79, result.targetWidth);
        Assert.assertEquals(67, result.targetHeight);
        Assert.assertTrue(result.hasNativeBbox());
        Assert.assertEquals(1920, result.imageWidth);
        Assert.assertEquals(1080, result.imageHeight);
        Assert.assertEquals(1, DetectionOverlayMapper.fromOpencvStainDetect(result, 1920, 1080).size());
    }

    @Test
    public void fromNativeSummary_failureWithoutTargetFile() {
        String summary = "{\"ok\":false,\"code\":-3,\"reason\":\"no target meets min_target_area_px\",\"files\":[]}";
        OpencvStainDetectResult result = OpencvStainDetectResultMapper.fromNativeSummary(
                summary, 1920, 1080, 200L, StainDetectSource.LIVE);

        Assert.assertFalse(result.success);
        Assert.assertEquals(-3, result.code);
        Assert.assertTrue(result.message.contains("no target"));
        Assert.assertTrue(DetectionOverlayMapper.fromOpencvStainDetect(result, 1920, 1080).isEmpty());
    }

    @Test
    public void parseSummary_handlesEmptyJson() {
        OpencvStainDetectJson.Summary summary = OpencvStainDetectJson.parseSummary("");
        Assert.assertFalse(summary.ok);
        Assert.assertEquals(-1, summary.code);
    }
}
