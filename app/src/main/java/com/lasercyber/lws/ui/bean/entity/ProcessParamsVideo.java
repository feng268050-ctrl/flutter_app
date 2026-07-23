package com.lasercyber.lws.ui.bean.entity;

import androidx.room.Entity;
import androidx.room.PrimaryKey;

import com.lasercyber.lws.ui.common.constant.ModelConstant;

import java.io.Serializable;

import lombok.Data;

/**
 * 工艺视频
 */
@Data
@Entity(tableName = "t_params_process_video")
public class ProcessParamsVideo implements Serializable {
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
     * 工艺参数 JSON 文本（Gson 序列化的 {@link com.lasercyber.lws.ui.bean.entity.ProcessParametersData}）
     */
    private String processParametersJson;
    /**
     * 工艺类型
     * {@link ModelConstant}
     */
    private Integer processType;
    /**
     * 材料类型（与 multipart {@code material_type}、{@code MaterialTypeEnum} 一致）
     */
    private Integer materialType;
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
    /**
     * 业务 UUID，入库时生成
     */
    private String videoId;
    /**
     * 分辨率文本，如 1280x720
     */
    private String resolution;
    /**
     * 上传状态，见 {@link com.lasercyber.lws.ui.common.constant.VideoUploadStatus}
     */
    private int uploadStatus;
    /**
     * 预留：上传进度 0–100；当前元数据流程保持 0
     */
    private int uploadProgress;
    /**
     * 封面预签名上传成功后的公开 URL（可为空）
     */
    private String coverUrl;
    /**
     * 预留：云端视频 URL（可为空）
     */
    private String videoUrl;
}
