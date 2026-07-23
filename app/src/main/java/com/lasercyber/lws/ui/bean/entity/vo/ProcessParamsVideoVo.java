package com.lasercyber.lws.ui.bean.entity.vo;

import androidx.room.PrimaryKey;

import com.lasercyber.lws.ui.common.constant.ModelConstant;

import java.io.Serializable;

import lombok.Data;

@Data
public class ProcessParamsVideoVo implements Serializable {
    /**
     * id
     */
    @PrimaryKey(autoGenerate = true)
    private long id;
    /**
     * 视频路径
     */
    private String videoPath;
    /**
     * 工艺类型
     * {@link ModelConstant}
     */
    private Integer processType;
    /**
     * 材料类型
     */
    private Integer materialType;
    /**
     * 工艺参数 JSON 文本（与 {@link com.lasercyber.lws.ui.bean.entity.ProcessParamsVideo#getProcessParametersJson()} 一致）
     */
    private String processParametersJson;
    /**
     * 文件大小
     */
    private long fileSize;
    /**
     * 时长（毫秒）
     */
    private long duration;
    /**
     * 创建时间 时间戳
     */
    private Long createTime;
    private String videoId;
    private String resolution;
    private int uploadStatus;
    private int uploadProgress;
    private String coverUrl;
    private String videoUrl;
}
