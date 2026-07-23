package com.lasercyber.lws.ai.stain;
import com.lasercyber.lws.ai.model.OpencvDetectCodes;
import com.lasercyber.lws.ai.model.OpencvStainDetectResult;
import com.lasercyber.lws.ai.model.StainAuditStatus;
import com.lasercyber.lws.ai.model.StainDetectSource;
import com.lasercyber.lws.ai.stain.OpencvStainDetectResultMapper;
import com.lasercyber.lws.ai.stain.StainAuditStatusMapper;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class StainAuditStatusMapperTest {

    @Test
    public void detectFailed_isUploadEligible() {
        OpencvStainDetectResult result = OpencvStainDetectResultMapper.appError(
                OpencvDetectCodes.DETECT_FAILED.code(),
                OpencvDetectCodes.REASON_INSUFFICIENT_REGIONS_AFTER_ERODE,
                1L,
                StainDetectSource.LIVE);
        StainAuditStatusMapper.Mapped mapped = StainAuditStatusMapper.mapLiveWeld(result);
        assertEquals(StainAuditStatus.DETECT_FAILED, mapped.status);
        assertTrue(mapped.uploadEligible);
    }

    @Test
    public void frameRejected_isNotUploadEligible() {
        OpencvStainDetectResult result = OpencvStainDetectResultMapper.appError(
                OpencvDetectCodes.FRAME_REJECTED.code(),
                OpencvDetectCodes.REASON_OVEREXPOSED,
                1L,
                StainDetectSource.LIVE);
        StainAuditStatusMapper.Mapped mapped = StainAuditStatusMapper.mapLiveWeld(result);
        assertEquals(StainAuditStatus.INTERNAL_FILTERED, mapped.status);
        assertFalse(mapped.uploadEligible);
    }

    @Test
    public void stainConfirmed_isNotUploadEligible() {
        OpencvStainDetectResult result = new OpencvStainDetectResult(
                true,
                0,
                "target",
                100.0,
                200.0,
                10,
                20,
                30,
                40,
                1920,
                1080,
                StainDetectSource.LIVE,
                1L,
                "red");
        StainAuditStatusMapper.Mapped mapped = StainAuditStatusMapper.mapLiveWeld(result);
        assertEquals(StainAuditStatus.STAIN_CONFIRMED, mapped.status);
        assertFalse(mapped.uploadEligible);
    }
}
