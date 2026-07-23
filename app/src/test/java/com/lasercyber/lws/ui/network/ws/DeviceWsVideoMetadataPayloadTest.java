package com.lasercyber.lws.ui.network.ws;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import com.lasercyber.lws.ui.bean.entity.ProcessParamsVideo;

import org.junit.Test;

import java.util.Map;

public class DeviceWsVideoMetadataPayloadTest {

    @Test
    public void fromRow_camelCaseExcludesIdAndPath() {
        ProcessParamsVideo row = new ProcessParamsVideo();
        row.setId(99L);
        row.setVideoPath("/data/video.mp4");
        row.setVideoId("550e8400-e29b-41d4-a716-446655440000");
        row.setProcessType(3);
        row.setMaterialType(1);
        row.setFileSize(2048L);
        row.setDuration(1500L);
        row.setCreateTime(1_700_000_000_000L);
        row.setResolution("1920x1080");
        row.setUploadStatus(1);
        row.setUploadProgress(0);
        row.setCoverUrl("https://cdn/cover.jpg");
        row.setVideoUrl(null);
        row.setProcessParametersJson("{\"k\":1}");

        Map<String, Object> m = DeviceWsVideoMetadataPayload.fromRow(row);
        assertFalse(m.containsKey("id"));
        assertFalse(m.containsKey("videoPath"));
        assertFalse(m.containsKey("status"));
        assertEquals("550e8400-e29b-41d4-a716-446655440000", m.get("videoId"));
        assertEquals(3, m.get("processType"));
        assertEquals(1, m.get("materialType"));
        assertEquals(2048L, m.get("fileSize"));
        assertEquals(1500L, m.get("duration"));
        assertEquals(1_700_000_000_000L, m.get("createTime"));
        assertEquals("1920x1080", m.get("resolution"));
        assertEquals(1, m.get("uploadStatus"));
        assertEquals(0, m.get("uploadProgress"));
        assertEquals("https://cdn/cover.jpg", m.get("coverUrl"));
        assertTrue(m.containsKey("processParametersJson"));
        assertEquals("{\"k\":1}", m.get("processParametersJson"));
    }
}
