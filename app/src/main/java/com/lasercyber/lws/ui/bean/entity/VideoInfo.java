package com.lasercyber.lws.ui.bean.entity;

import android.graphics.Bitmap;

import java.util.Date;

import lombok.Data;
import lombok.experimental.Accessors;

@Data
@Accessors(chain = true)
public class VideoInfo {
    private String fileName;      // 文件名（含后缀）
    private long fileSize;      // 文件大小（格式化后，如1.2MB）
    private long duration;        // 时长（毫秒）
    private String durationStr;   // 时长字符串（如01:23:45）
    private String resolution;    // 显示分辨率（如1920x1080）
    private Bitmap coverBitmap;   // 第一帧封面
    private Date recordingTime; // 录制时间
}
