package com.lasercyber.lws.ui.bean.http;

import org.junit.Assert;
import org.junit.Test;

import java.util.Calendar;
import java.util.TimeZone;

public class CameraShowTimeRequestTest {

    @Test
    public void create_enable1_usesUtcNow() {
        CameraShowTimeRequest request = CameraShowTimeRequest.create(1, 20, 30, true);
        Assert.assertEquals(Integer.valueOf(1), request.getEnable());
        Assert.assertEquals(Integer.valueOf(20), request.getPositionx());
        Assert.assertEquals(Integer.valueOf(30), request.getPositiony());

        Calendar utc = Calendar.getInstance(TimeZone.getTimeZone("UTC"));
        Assert.assertEquals(Integer.valueOf(utc.get(Calendar.YEAR)), request.getYear());
        Assert.assertEquals(Integer.valueOf(utc.get(Calendar.MONTH) + 1), request.getMonth());
        Assert.assertEquals(Integer.valueOf(utc.get(Calendar.DAY_OF_MONTH)), request.getDay());
        Assert.assertEquals(Integer.valueOf(utc.get(Calendar.HOUR_OF_DAY)), request.getHour());
        Assert.assertEquals(Integer.valueOf(utc.get(Calendar.MINUTE)), request.getMinute());
        Assert.assertEquals(Integer.valueOf(utc.get(Calendar.SECOND)), request.getSec());
    }

    @Test
    public void create_enable0_zerosDatetime() {
        CameraShowTimeRequest request = CameraShowTimeRequest.create(0, 10, 10, false);
        Assert.assertEquals(Integer.valueOf(0), request.getEnable());
        Assert.assertEquals(Integer.valueOf(0), request.getYear());
        Assert.assertEquals(Integer.valueOf(0), request.getMonth());
        Assert.assertEquals(Integer.valueOf(0), request.getDay());
        Assert.assertEquals(Integer.valueOf(0), request.getHour());
        Assert.assertEquals(Integer.valueOf(0), request.getMinute());
        Assert.assertEquals(Integer.valueOf(0), request.getSec());
    }
}
