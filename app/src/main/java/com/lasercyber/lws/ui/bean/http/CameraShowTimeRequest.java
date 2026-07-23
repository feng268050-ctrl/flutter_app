package com.lasercyber.lws.ui.bean.http;

import com.google.gson.annotations.SerializedName;

import java.io.Serializable;
import java.util.Calendar;
import java.util.TimeZone;

import lombok.Data;
import lombok.experimental.Accessors;

/** JSON body for camera {@code PUT /System/showtime}. */
@Accessors(chain = true)
@Data
public class CameraShowTimeRequest implements Serializable {
    private Integer enable;
    private Integer positionx;
    private Integer positiony;
    private Integer year;

    @SerializedName("mon")
    private Integer month;

    private Integer day;
    private Integer hour;

    @SerializedName("min")
    private Integer minute;

    private Integer sec;

    public static CameraShowTimeRequest create(int enable, int positionX, int positionY, boolean useUtcNow) {
        CameraShowTimeRequest request = new CameraShowTimeRequest()
                .setEnable(enable)
                .setPositionx(positionX)
                .setPositiony(positionY);
        if (useUtcNow) {
            fillUtcNow(request);
        } else {
            fillZeros(request);
        }
        return request;
    }

    public static void fillUtcNow(CameraShowTimeRequest request) {
        Calendar calendar = Calendar.getInstance(TimeZone.getTimeZone("UTC"));
        request.setYear(calendar.get(Calendar.YEAR));
        request.setMonth(calendar.get(Calendar.MONTH) + 1);
        request.setDay(calendar.get(Calendar.DAY_OF_MONTH));
        request.setHour(calendar.get(Calendar.HOUR_OF_DAY));
        request.setMinute(calendar.get(Calendar.MINUTE));
        request.setSec(calendar.get(Calendar.SECOND));
    }

    public static void fillZeros(CameraShowTimeRequest request) {
        request.setYear(0);
        request.setMonth(0);
        request.setDay(0);
        request.setHour(0);
        request.setMinute(0);
        request.setSec(0);
    }
}
