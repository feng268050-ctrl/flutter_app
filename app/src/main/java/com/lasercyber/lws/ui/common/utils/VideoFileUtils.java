package com.lasercyber.lws.ui.common.utils;

import android.util.Log;

import com.lasercyber.lws.ui.bean.entity.VideoInfo;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

import java.io.File;
import java.util.Date;

/**
 * 视频文件工具类
 */
public class VideoFileUtils {
    private static final String TAG = LogTAGConstant.VideoFileUtils;

    /**
     * 读取视频的信息（时长、封面等与 {@link VideoCoverExtractor} 共用同一套抽帧策略）
     *
     * @param videoPath
     * @return
     */
    public static VideoInfo readVideoFileInfo(String videoPath) {
        File videoFile = new File(videoPath);
        if (!videoFile.exists()) {
            Log.e(TAG, "视频文件不存在：" + videoPath);
            return null;
        }
        VideoInfo videoInfo = new VideoInfo();
        videoInfo.setFileName(videoFile.getName());
        videoInfo.setFileSize(videoFile.length());
        videoInfo.setRecordingTime(new Date(videoFile.lastModified()));

        VideoCoverExtractor.Probe probe = VideoCoverExtractor.probeVideoFile(videoFile);
        videoInfo.setDuration(probe.durationMs);
        videoInfo.setResolution(probe.resolution);
        videoInfo.setCoverBitmap(probe.coverBitmap);
        return videoInfo;
    }
}
