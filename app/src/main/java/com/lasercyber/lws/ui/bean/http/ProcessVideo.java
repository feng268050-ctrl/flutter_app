package com.lasercyber.lws.ui.bean.http;

import java.io.Serializable;
import java.util.Date;

import lombok.Data;
import lombok.experimental.Accessors;

@Data
@Accessors(chain = true)
public class ProcessVideo implements Serializable {
    /**
     * 封面地址
     */
    private String coverUrl;
    /**
     * 视频地址
     */
    private String videoUrl;
    /**
     * 视频时长
     */
    private Long videoDuration;
    /**
     * 视频名称
     */
    private String videoName;
    /**
     * 视频录制时间
     */
    private Date recordingTime;
    /**
     * 工艺类型（关联process_type字典）
     */
    private Integer processType;
    /**
     * 设备Sn
     */
    private String deviceSn;
}
