package com.lasercyber.lws.ui.network.http.local;

import com.lasercyber.lws.ui.network.ws.DeviceWsRowId;
import com.lasercyber.lws.ui.network.ws.DeviceWsVideoListPayload;

import org.junit.Assert;
import org.junit.Test;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

public class DeviceLocalHttpServerTest {

    @Test
    public void parsePageParams_defaults() {
        int[] p = DeviceLocalHttpServer.parsePageParams(Collections.emptyMap());
        Assert.assertEquals(1, p[0]);
        Assert.assertEquals(10, p[1]);
    }

    @Test
    public void parsePageParams_clampsPageSize() {
        Map<String, String> parms = new HashMap<>();
        parms.put("page", "2");
        parms.put("pageSize", "500");
        int[] p = DeviceLocalHttpServer.parsePageParams(parms);
        Assert.assertEquals(2, p[0]);
        Assert.assertEquals(100, p[1]);
    }

    @Test
    public void parseByteRange_closedInterval() {
        long[] r = DeviceLocalHttpServer.parseByteRange("bytes=0-1023", 5000);
        Assert.assertNotNull(r);
        Assert.assertEquals(0, r[0]);
        Assert.assertEquals(1023, r[1]);
    }

    @Test
    public void parseByteRange_openEnded() {
        long[] r = DeviceLocalHttpServer.parseByteRange("bytes=1000-", 5000);
        Assert.assertNotNull(r);
        Assert.assertEquals(1000, r[0]);
        Assert.assertEquals(4999, r[1]);
    }

    @Test
    public void parseByteRange_suffix() {
        long[] r = DeviceLocalHttpServer.parseByteRange("bytes=-500", 5000);
        Assert.assertNotNull(r);
        Assert.assertEquals(4500, r[0]);
        Assert.assertEquals(4999, r[1]);
    }

    @Test
    public void parseByteRange_nullMeansFullFile() {
        Assert.assertNull(DeviceLocalHttpServer.parseByteRange(null, 100));
    }

    @Test
    public void parseByteRange_unsatisfiable() {
        long[] r = DeviceLocalHttpServer.parseByteRange("bytes=9000-9999", 5000);
        Assert.assertNotNull(r);
        Assert.assertEquals(-1, r[0]);
    }

    @Test
    public void parseQueryFilters_processTypeMaterialTypeAndDates() {
        Map<String, String> parms = new HashMap<>();
        parms.put("processType", "1");
        parms.put("materialType", "4");
        parms.put("startDate", "2026-05-01");
        parms.put("endDate", "2026-05-18");
        DeviceWsVideoListPayload.ListFilters f = DeviceLocalHttpServer.parseQueryFilters(parms);
        Assert.assertEquals(Integer.valueOf(1), f.processType);
        Assert.assertEquals(Integer.valueOf(4), f.materialType);
        Assert.assertEquals(
                DeviceWsVideoListPayload.startOfDayMillisFromCalendarDate("2026-05-01"),
                f.startDate);
        Assert.assertEquals(
                DeviceWsVideoListPayload.endOfDayMillisFromCalendarDate("2026-05-18"),
                f.endDate);
    }

    @Test
    public void rowId_parseDecimalString_forHttpPath() {
        Assert.assertEquals(Long.valueOf(42L), DeviceWsRowId.parseDecimalString("42"));
        Assert.assertNull(DeviceWsRowId.parseDecimalString("not-a-number"));
    }

    @Test
    public void parseQueryFilters_orderSnakeCase() {
        Map<String, String> asc = new HashMap<>();
        asc.put("order", "date_asc");
        Assert.assertTrue(DeviceLocalHttpServer.parseQueryFilters(asc).createTimeAscending);

        Map<String, String> desc = new HashMap<>();
        desc.put("order", "date_desc");
        Assert.assertFalse(DeviceLocalHttpServer.parseQueryFilters(desc).createTimeAscending);
    }

    @Test
    public void parseQueryFilters_uploadStatus() {
        Map<String, String> parms = new HashMap<>();
        parms.put("uploadStatus", "2");
        Assert.assertEquals(Integer.valueOf(2),
                DeviceLocalHttpServer.parseQueryFilters(parms).uploadStatus);
    }
}
