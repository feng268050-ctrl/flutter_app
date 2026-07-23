package com.lasercyber.lws.ai.stain;
import com.lasercyber.lws.ai.NativeBridge;
import com.lasercyber.lws.ai.model.AiStainDetectResult;
import com.lasercyber.lws.ai.model.OpencvStainDetectResult;
import com.lasercyber.lws.ai.model.StainDetectSource;
import com.lasercyber.lws.ai.stain.AiStainDetectResultMapper;

import org.junit.Assert;
import org.junit.Test;

import java.util.ArrayList;
import java.util.List;

public class AiStainDetectResultMapperTest {

    @Test
    public void processVideoStainDetectRow_includesTargetBox() {
        OpencvStainDetectResult lensDet = new OpencvStainDetectResult(
                true,
                0,
                "",
                882.0,
                536.0,
                1920,
                1080,
                StainDetectSource.OFFLINE,
                500L);
        AiStainDetectResult mapped = AiStainDetectResultMapper.processVideoStainDetectRow(
                lensDet, 1920, 1080, 500L, StainDetectSource.OFFLINE);
        Assert.assertEquals(1, mapped.boxes.size());
        Assert.assertEquals("contamination", mapped.boxes.get(0).label);
    }

    @Test
    public void fromStainInferOutcome_mapsSuccessFields() {
        NativeBridge.StainBox box = new NativeBridge.StainBox(10f, 20f, 30f, 40f, 0, 0.95f);
        NativeBridge.StainInferOutcome outcome = new NativeBridge.StainInferOutcome(
                0,
                "",
                "live_infer",
                2,
                "HEAVY",
                "heavy stain detected",
                1920,
                1080,
                new NativeBridge.StainBox[]{box},
                false,
                1);
        AiStainDetectResult mapped = AiStainDetectResultMapper.fromStainInferOutcome(
                outcome, 123L, "live_infer");
        Assert.assertTrue(mapped.success);
        Assert.assertEquals(2, mapped.level);
        Assert.assertEquals("HEAVY", mapped.status);
        Assert.assertEquals("live_infer", mapped.source);
        Assert.assertEquals(1, mapped.boxes.size());
    }

    @Test
    public void fromStainInferOutcome_mapsFailureFields() {
        NativeBridge.StainInferOutcome outcome = new NativeBridge.StainInferOutcome(
                -1,
                "invalid buffer",
                "",
                -1,
                "ERROR",
                "",
                0,
                0,
                new NativeBridge.StainBox[0],
                false,
                0);
        AiStainDetectResult mapped = AiStainDetectResultMapper.fromStainInferOutcome(
                outcome, 456L, "live_infer");
        Assert.assertFalse(mapped.success);
        Assert.assertEquals(-1, mapped.code);
        Assert.assertEquals("invalid buffer", mapped.message);
    }

    @Test
    public void isNonDisplayOverlayStatus_hidesInternalPlaceholders() {
        Assert.assertTrue(AiStainDetectResultMapper.isNonDisplayOverlayStatus("RKNN_OFF"));
        Assert.assertTrue(AiStainDetectResultMapper.isNonDisplayOverlayStatus("rknn_off"));
        Assert.assertTrue(AiStainDetectResultMapper.isNonDisplayOverlayStatus("DISABLED"));
        Assert.assertFalse(AiStainDetectResultMapper.isNonDisplayOverlayStatus("HEAVY"));
        Assert.assertFalse(AiStainDetectResultMapper.isNonDisplayOverlayStatus(null));
    }

    @Test
    public void normalizeStatus_mapsLegacyValues() {
        Assert.assertEquals("HEAVY", AiStainDetectResultMapper.normalizeStatus("stain_heavy"));
        Assert.assertEquals("MILD", AiStainDetectResultMapper.normalizeStatus("stain_mild"));
        Assert.assertEquals("CLEAN", AiStainDetectResultMapper.normalizeStatus("csl:clean"));
        Assert.assertEquals("CLEAN", AiStainDetectResultMapper.normalizeStatus("clean"));
    }

    @Test
    public void sanitizeBoxes_keepsValidBox() {
        List<AiStainDetectResultMapper.PixelBox> raw = new ArrayList<>();
        raw.add(new AiStainDetectResultMapper.PixelBox(10, 10, 30, 40, 0, "cls=0", 0.95));
        List<AiStainDetectResultMapper.PixelBox> sanitized =
                AiStainDetectResultMapper.sanitizePixelBoxes(raw, 100, 100);
        Assert.assertEquals(1, sanitized.size());
    }

    @Test
    public void sanitizeBoxes_dropsCorruptBatch() {
        List<AiStainDetectResultMapper.PixelBox> raw = new ArrayList<>();
        for (int i = 0; i < 80; i++) {
            raw.add(new AiStainDetectResultMapper.PixelBox(0, 0, 0, 0, -1, "", 1.0));
        }
        List<AiStainDetectResultMapper.PixelBox> sanitized =
                AiStainDetectResultMapper.sanitizePixelBoxes(raw, 1920, 1080);
        Assert.assertTrue(sanitized.isEmpty());
    }
}

