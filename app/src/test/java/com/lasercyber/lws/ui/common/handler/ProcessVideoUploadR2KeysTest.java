package com.lasercyber.lws.ui.common.handler;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;

import org.junit.Test;

public class ProcessVideoUploadR2KeysTest {

    @Test
    public void videoObjectKey_usesVideosSegmentAndUuidExt() {
        String id = "a1b2c3d4-e5f6-7890-abcd-ef1234567890";
        assertEquals(
                "uploads/devices/SN001/videos/2026-04-20/" + id + ".mp4",
                ProcessVideoUploadR2Keys.videoObjectKey("SN001", "2026-04-20", id, "mp4"));
    }

    @Test
    public void videoObjectKey_coverJpgSameLayout() {
        String id = "a1b2c3d4-e5f6-7890-abcd-ef1234567890";
        String key = ProcessVideoUploadR2Keys.videoObjectKey("dev", "2026-01-02", id, "jpg");
        assertFalse(key.contains("/covers/"));
        assertEquals("uploads/devices/dev/videos/2026-01-02/" + id + ".jpg", key);
    }

    @Test
    public void videoExtFromPath_trimsAndLowercases() {
        assertEquals("mp4", ProcessVideoUploadR2Keys.videoExtFromPath("/foo/bar.MP4"));
        assertEquals("webm", ProcessVideoUploadR2Keys.videoExtFromPath("x.WEBM"));
    }

    @Test
    public void yyyyMmDdFromCreateTimeMillis_isoShape() {
        String d = ProcessVideoUploadR2Keys.yyyyMmDdFromCreateTimeMillis(1_700_000_000_000L);
        assertEquals(10, d.length());
        assertEquals('-', d.charAt(4));
        assertEquals('-', d.charAt(7));
    }
}
