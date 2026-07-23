package com.lasercyber.lws.ui.bean.http;

import android.icu.util.Calendar;

import com.google.gson.annotations.SerializedName;

import java.io.Serializable;
import java.util.Date;

import lombok.Data;
import lombok.experimental.Accessors;

@Accessors(chain = true)
@Data
public class CameraTime implements Serializable {
    // 年份
    private Integer year;

    // 月份（JSON 中字段为 mon）
    @SerializedName("mon")
    private Integer month;

    // 日期
    private Integer day;

    // 小时
    private Integer hour;

    // 分钟（JSON 中字段为 min）
    @SerializedName("min")
    private Integer minute;

    // 秒
    private Integer sec;

    public static CameraTime createNow() {
        Date date = new Date();
        Calendar calendar = Calendar.getInstance();
        calendar.setTime(date);

        // 替代 getYear()：获取完整年份（2025 而非 125）
        int year = calendar.get(Calendar.YEAR); // 输出 2025
        // 替代 getMonth()：月份从 0 开始（0=1月，11=12月），需+1得到直观月份
        int month = calendar.get(Calendar.MONTH) + 1; // 输出 10（10月）
        // 替代 getDay()：获取日期（1-31）
        int day = calendar.get(Calendar.DAY_OF_MONTH); // 输出 1
        // 小时（24小时制）
        int hour = calendar.get(Calendar.HOUR_OF_DAY); // 输出 1
        // 分钟
        int minute = calendar.get(Calendar.MINUTE); // 输出 1
        // 秒
        int second = calendar.get(Calendar.SECOND); // 输出 0
        CameraTime cameraTime = new CameraTime();
        cameraTime.setYear(year)
                .setMonth(month)
                .setDay(day)
                .setHour(hour)
                .setMinute(minute)
                .setSec(second);
        return cameraTime;
    }

}
