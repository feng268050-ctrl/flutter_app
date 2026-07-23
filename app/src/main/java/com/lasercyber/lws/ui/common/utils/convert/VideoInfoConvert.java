package com.lasercyber.lws.ui.common.utils.convert;

import com.lasercyber.lws.ui.bean.entity.VideoInfo;
import com.lasercyber.lws.ui.bean.http.ProcessVideo;
import com.lasercyber.lws.ui.common.device.DeviceIdentity;

public class VideoInfoConvert {
    /**
     * 转换为ProcessVideo
     *
     * @param videoInfo
     * @param imageUrl
     * @return
     */
    public static ProcessVideo convertToProcessVideo(VideoInfo videoInfo, String imageUrl) {
        ProcessVideo processVideo = new ProcessVideo();
        processVideo.setVideoName(videoInfo.getFileName())
                .setCoverUrl(imageUrl)
                .setVideoDuration(videoInfo.getDuration())
                .setDeviceSn(DeviceIdentity.getDeviceSnSafely())
                .setRecordingTime(videoInfo.getRecordingTime());
        return processVideo;
    }
}
