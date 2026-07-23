package com.lasercyber.lws.ui.network.ws;

import com.blankj.utilcode.util.GsonUtils;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.lasercyber.lws.ui.bean.entity.vo.ProcessParamsVideoVo;

import org.junit.Assert;
import org.junit.Test;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public class DeviceWsVideoListPayloadTest {

    @Test
    public void normalize_defaultsWhenEmptyPayload() {
        int[] p = DeviceWsVideoListPayload.normalizePageAndSize(new JsonObject());
        Assert.assertEquals(1, p[0]);
        Assert.assertEquals(10, p[1]);
    }

    @Test
    public void normalize_clampsPageSize() {
        JsonObject o = new JsonObject();
        o.addProperty("page", 1);
        o.addProperty("page_size", 9999);
        int[] p = DeviceWsVideoListPayload.normalizePageAndSize(o);
        Assert.assertEquals(1, p[0]);
        Assert.assertEquals(100, p[1]);
    }

    @Test
    public void normalize_secondPage() {
        JsonObject o = new JsonObject();
        o.addProperty("page", 2);
        o.addProperty("page_size", 3);
        int[] p = DeviceWsVideoListPayload.normalizePageAndSize(o);
        Assert.assertEquals(2, p[0]);
        Assert.assertEquals(3, p[1]);
    }

    @Test
    public void parseListFilters_emptyPayload() {
        DeviceWsVideoListPayload.ListFilters f = DeviceWsVideoListPayload.parseListFilters(new JsonObject());
        Assert.assertNull(f.processType);
        Assert.assertNull(f.materialType);
        Assert.assertNull(f.startDate);
        Assert.assertNull(f.endDate);
        Assert.assertFalse(f.createTimeAscending);
        Assert.assertNull(f.uploadStatus);
    }

    @Test
    public void parseListFilters_readsUploadStatus() {
        JsonObject o = new JsonObject();
        o.addProperty("upload_status", 3);
        Assert.assertEquals(Integer.valueOf(3),
                DeviceWsVideoListPayload.parseListFilters(o).uploadStatus);
    }

    @Test
    public void parseCreateTimeAscending_dateAscAndDesc() {
        Assert.assertTrue(DeviceWsVideoListPayload.parseCreateTimeAscending("date_asc"));
        Assert.assertFalse(DeviceWsVideoListPayload.parseCreateTimeAscending("date_desc"));
        Assert.assertFalse(DeviceWsVideoListPayload.parseCreateTimeAscending(null));
        Assert.assertFalse(DeviceWsVideoListPayload.parseCreateTimeAscending("invalid"));
    }

    @Test
    public void parseListFilters_readsOrderFromPayload() {
        JsonObject asc = new JsonObject();
        asc.addProperty("order", "date_asc");
        Assert.assertTrue(DeviceWsVideoListPayload.parseListFilters(asc).createTimeAscending);

        JsonObject desc = new JsonObject();
        desc.addProperty("order", "date_desc");
        Assert.assertFalse(DeviceWsVideoListPayload.parseListFilters(desc).createTimeAscending);
    }

    @Test
    public void parseListFilters_readsSnakeCaseCalendarDates() {
        JsonObject o = new JsonObject();
        o.addProperty("process_type", 2);
        o.addProperty("material_type", 3);
        o.addProperty("start_date", "2026-01-01");
        o.addProperty("end_date", "2026-01-02");
        DeviceWsVideoListPayload.ListFilters f = DeviceWsVideoListPayload.parseListFilters(o);
        Assert.assertEquals(Integer.valueOf(2), f.processType);
        Assert.assertEquals(Integer.valueOf(3), f.materialType);
        Assert.assertEquals(
                DeviceWsVideoListPayload.startOfDayMillisFromCalendarDate("2026-01-01"),
                f.startDate);
        Assert.assertEquals(
                DeviceWsVideoListPayload.endOfDayMillisFromCalendarDate("2026-01-02"),
                f.endDate);
    }

    @Test
    public void parseListFilters_ignoresNumericDateFields() {
        JsonObject o = new JsonObject();
        o.addProperty("start_date", 1_700_000_000_000L);
        o.addProperty("end_date", 1_700_086_400_000L);
        DeviceWsVideoListPayload.ListFilters f = DeviceWsVideoListPayload.parseListFilters(o);
        Assert.assertNull(f.startDate);
        Assert.assertNull(f.endDate);
    }

    @Test
    public void deleteVideoAckPayloadShape_matchesUploadVideoAck() {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("success", false);
        data.put("message", "video_not_found");
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("request_id", "req-del-1");
        payload.put("data", data);
        @SuppressWarnings("unchecked")
        Map<String, Object> dataOut = (Map<String, Object>) payload.get("data");
        Assert.assertEquals("req-del-1", payload.get("request_id"));
        Assert.assertFalse((Boolean) dataOut.get("success"));
        Assert.assertEquals("video_not_found", dataOut.get("message"));
    }

    @Test
    public void normalize_invalidPageFallsBack() {
        JsonObject o = new JsonObject();
        o.addProperty("page", 0);
        o.addProperty("page_size", 5);
        int[] p = DeviceWsVideoListPayload.normalizePageAndSize(o);
        Assert.assertEquals(1, p[0]);
        Assert.assertEquals(5, p[1]);
    }

    @Test
    public void voToRow_includesProcessParametersNullWhenNoJson() {
        ProcessParamsVideoVo vo = new ProcessParamsVideoVo();
        vo.setId(42L);
        vo.setVideoPath("/tmp/a.mp4");
        vo.setProcessType(1);
        vo.setMaterialType(2);
        vo.setFileSize(100L);
        vo.setDuration(5000L);
        vo.setCreateTime(1_700_000_000_000L);
        vo.setVideoId("vid-uuid");
        vo.setResolution("1280x720");
        vo.setUploadStatus(1);
        vo.setUploadProgress(0);
        vo.setCoverUrl("https://cdn/c.jpg");
        vo.setVideoUrl(null);
        vo.setProcessParametersJson(null);

        Map<String, Object> row = DeviceWsVideoListPayload.voToRow(vo);
        Assert.assertTrue(row.containsKey("processParameters"));
        Assert.assertNull(row.get("processParameters"));
        Assert.assertFalse(row.containsKey("processData"));
        Assert.assertFalse(row.containsKey("status"));
        Assert.assertFalse(row.containsKey("id"));
        Assert.assertFalse(row.containsKey("videoPath"));
        Assert.assertEquals("vid-uuid", row.get("videoId"));
        Assert.assertEquals(1, row.get("processType"));
        Assert.assertEquals(1, row.get("uploadStatus"));
        Assert.assertEquals("https://cdn/c.jpg", row.get("coverUrl"));
    }

    @Test
    public void voToRow_processParametersParsesJsonObject() {
        ProcessParamsVideoVo vo = new ProcessParamsVideoVo();
        vo.setProcessParametersJson("{\"laserPower\":45}");
        Map<String, Object> row = DeviceWsVideoListPayload.voToRow(vo);
        Assert.assertTrue(row.get("processParameters") instanceof JsonObject);
        JsonObject obj = (JsonObject) row.get("processParameters");
        Assert.assertEquals(45, obj.get("laserPower").getAsInt());
    }

    @Test
    public void voToRow_processParametersOmitsId() {
        ProcessParamsVideoVo vo = new ProcessParamsVideoVo();
        vo.setProcessParametersJson("{\"id\":2034237074190352385,\"name\":\"666\",\"laserPower\":48}");
        Map<String, Object> row = DeviceWsVideoListPayload.voToRow(vo);
        JsonObject obj = (JsonObject) row.get("processParameters");
        Assert.assertFalse(obj.has("id"));
        Assert.assertEquals("666", obj.get("name").getAsString());
        Assert.assertEquals(48, obj.get("laserPower").getAsInt());
    }

    @Test
    public void voToRow_invalidJsonYieldsNullProcessParameters() {
        ProcessParamsVideoVo vo = new ProcessParamsVideoVo();
        vo.setProcessParametersJson("not-json");
        Map<String, Object> row = DeviceWsVideoListPayload.voToRow(vo);
        Assert.assertTrue(row.containsKey("processParameters"));
        Assert.assertNull(row.get("processParameters"));
    }

    @Test
    public void voToRow_blankJsonYieldsNullProcessParameters() {
        ProcessParamsVideoVo vo = new ProcessParamsVideoVo();
        vo.setProcessParametersJson("   \n\t");
        Map<String, Object> row = DeviceWsVideoListPayload.voToRow(vo);
        Assert.assertNull(row.get("processParameters"));
    }

    @Test
    public void parseProcessParameters_nonObjectJsonYieldsNull() {
        Assert.assertNull(DeviceWsVideoListPayload.parseProcessParametersObjectOrNull("[1,2]"));
        Assert.assertNull(DeviceWsVideoListPayload.parseProcessParametersObjectOrNull("\"x\""));
    }

    @Test
    public void videoListResponse_serializesProcessParametersObject() {
        ProcessParamsVideoVo vo = new ProcessParamsVideoVo();
        vo.setVideoId("v1");
        vo.setProcessParametersJson("{\"a\":true}");
        Map<String, Object> row = DeviceWsVideoListPayload.voToRow(vo);
        Map<String, Object> root = new LinkedHashMap<>();
        root.put("v", 1);
        root.put("type", "command.video_list_response");
        root.put("id", "out-id");
        root.put("ts", 1L);
        Map<String, Object> payload = new LinkedHashMap<>();
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("list", List.of(row));
        data.put("total", 1L);
        payload.put("request_id", "req");
        payload.put("data", data);
        root.put("payload", payload);
        String json = GsonUtils.toJson(root);
        JsonObject parsed = new JsonParser().parse(json).getAsJsonObject();
        JsonObject listItem = parsed.getAsJsonObject("payload").getAsJsonObject("data")
                .getAsJsonArray("list").get(0).getAsJsonObject();
        Assert.assertTrue(listItem.has("processParameters"));
        Assert.assertTrue(listItem.get("processParameters").isJsonObject());
        Assert.assertTrue(listItem.getAsJsonObject("processParameters").get("a").getAsBoolean());
    }

    @Test
    public void videoListResponsePayloadShape() {
        String requestId = "inbound-req-id-1";
        List<Map<String, Object>> list = DeviceWsVideoListPayload.rowsFromVos(List.of());
        Map<String, Object> dataMap = new LinkedHashMap<>();
        dataMap.put("list", list);
        dataMap.put("total", 20L);
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("request_id", requestId);
        payload.put("data", dataMap);
        Assert.assertEquals(requestId, payload.get("request_id"));
        @SuppressWarnings("unchecked")
        Map<String, Object> data = (Map<String, Object>) payload.get("data");
        Assert.assertNotNull(data);
        Assert.assertEquals(20L, data.get("total"));
        Assert.assertTrue(((List<?>) data.get("list")).isEmpty());
    }
}
