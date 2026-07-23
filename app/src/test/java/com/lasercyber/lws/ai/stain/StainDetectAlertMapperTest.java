package com.lasercyber.lws.ai.stain;
import com.lasercyber.lws.ai.model.AiStainDetectResult;
import com.lasercyber.lws.ai.model.NormalizedBox;
import com.lasercyber.lws.ai.model.OpencvStainDetectResult;
import com.lasercyber.lws.ai.model.StainDetectSource;
import com.lasercyber.lws.ai.stain.StainDetectAlertMapper;

import com.lasercyber.lws.ui.bean.event.LensCheckResultEvent;

import org.junit.Test;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

public class StainDetectAlertMapperTest {

    @Test
    public void toLensCheckResult_heavyTarget_emitsLevel2WithLiveSource() {
        OpencvStainDetectResult result = new OpencvStainDetectResult(
                true, 0, "target", 100.0, 200.0, 1920, 1080, StainDetectSource.LIVE, 1L);
        LensCheckResultEvent event = StainDetectAlertMapper.toLensCheckResult(result);
        assertNotNull(event);
        assertTrue(event.getLevel() >= 2);
        assertTrue(event.getMessage().contains("\"source\":\"live_stain_detect\""));
        assertFalse(event.getMessage().contains("productionAlert"));
    }

    @Test
    public void toLensCheckResult_cleanTarget_emitsLevel0() {
        OpencvStainDetectResult result = new OpencvStainDetectResult(
                true, 0, "clean", Double.NaN, Double.NaN, 1920, 1080, StainDetectSource.LIVE, 1L);
        LensCheckResultEvent event = StainDetectAlertMapper.toLensCheckResult(result);
        assertNotNull(event);
        assertTrue(event.getLevel() < 2);
    }

    @Test
    public void toLensCheckResult_failure_returnsNull() {
        OpencvStainDetectResult result = new OpencvStainDetectResult(
                false, -1, "busy", Double.NaN, Double.NaN, 0, 0, StainDetectSource.LIVE, 1L);
        assertNull(StainDetectAlertMapper.toLensCheckResult(result));
    }

    @Test
    public void isOfflineStainDetectMessage_filtersOfflineOnly() {
        assertTrue(StainDetectAlertMapper.isOfflineStainDetectMessage(
                "{\"source\":\"offline_stain_detect\"}"));
        assertFalse(StainDetectAlertMapper.isOfflineStainDetectMessage(
                "{\"source\":\"live_stain_detect\"}"));
        assertFalse(StainDetectAlertMapper.isOfflineStainDetectMessage("plain text"));
    }

    @Test
    public void toOfflineSummaryLensCheckResult_dirtySummary_emitsLevel2WithOfflineSource() {
        AiStainDetectResult summary = new AiStainDetectResult(
                true,
                0,
                2,
                OpencvStainDetectResult.OVERLAY_STATUS,
                "",
                640,
                360,
                java.util.Collections.singletonList(
                        NormalizedBox.fromPixelRect(10f, 20f, 30f, 40f, 640, 360, 0, "contamination", 1.0)),
                StainDetectSource.OFFLINE,
                5000L);
        LensCheckResultEvent event = StainDetectAlertMapper.toOfflineSummaryLensCheckResult(summary);
        assertNotNull(event);
        assertTrue(event.getLevel() >= 2);
        assertTrue(StainDetectAlertMapper.isOfflineStainDetectMessage(event.getMessage()));
    }

    @Test
    public void toOfflineSummaryLensCheckResult_cleanSummary_emitsLevel0WithOfflineSource() {
        AiStainDetectResult summary = new AiStainDetectResult(
                true,
                0,
                0,
                "CLEAN",
                "",
                640,
                360,
                java.util.Collections.emptyList(),
                StainDetectSource.OFFLINE,
                5000L);
        LensCheckResultEvent event = StainDetectAlertMapper.toOfflineSummaryLensCheckResult(summary);
        assertNotNull(event);
        assertTrue(event.getLevel() < 2);
        assertTrue(StainDetectAlertMapper.isOfflineStainDetectMessage(event.getMessage()));
    }
}
