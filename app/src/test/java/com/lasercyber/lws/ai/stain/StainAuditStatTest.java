package com.lasercyber.lws.ai.stain;
import com.lasercyber.lws.ai.model.OpencvDetectCodes;
import com.lasercyber.lws.ai.model.OpencvStainDetectResult;
import com.lasercyber.lws.ai.model.StainAuditStat;
import com.lasercyber.lws.ai.model.StainAuditStatus;
import com.lasercyber.lws.ai.model.StainDetectSource;
import com.lasercyber.lws.ai.stain.OpencvStainDetectResultMapper;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import com.lasercyber.lws.ui.common.utils.json.GsonInitUtils;

import org.junit.Before;
import org.junit.Test;

public class StainAuditStatTest {

    @Before
    public void setUp() {
        GsonInitUtils.initGson();
    }

    @Test
    public void serializesRequiredV1Fields() {
        OpencvStainDetectResult result = OpencvStainDetectResultMapper.appError(
                OpencvDetectCodes.DETECT_FAILED.code(),
                OpencvDetectCodes.REASON_NO_TARGET_AFTER_FILTER,
                1234L,
                StainDetectSource.LIVE);
        StainAuditStat stat = StainAuditStat.fromLiveDetect(StainAuditStatus.DETECT_FAILED, result, 42L);
        String json = GsonInitUtils.getGson().toJson(stat);
        assertTrue(json.contains("\"status\":\"DETECT_FAILED\""));
        assertTrue(json.contains("\"reason\":\"no_target_after_filter\""));
        assertTrue(json.contains("\"source\":\"live_stain_detect\""));
        assertTrue(json.contains("\"primary_result\":\"DETECT_FAILED\""));
        assertTrue(json.contains("\"created_at\":1234"));
        assertTrue(json.contains("\"frame_id\":42"));
        assertEquals(-3, stat.code);
    }
}
