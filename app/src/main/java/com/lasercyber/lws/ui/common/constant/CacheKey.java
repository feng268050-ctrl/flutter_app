package com.lasercyber.lws.ui.common.constant;

/**
 * 缓存key
 */
public class CacheKey {
    /**
     * 告警状态
     */
    public static final String WARN_STATUS_KEY="WarnStatus";
    /**
     * 设备状态缓存
     * 激光、吹起、告警
     */
    public static final String DEVICE_STATUS_KEY = "deviceStatus";
    /**
     * 设备数据
     * 吹气气压、泵源电流
     */
    public static final String DEVICE_DATA_KEY = "deviceData";
    /*
    * 设备数据
    * 基础数据, 升级模板数据
    * */
    public static final String DEVICE_INFO_KEY = "deviceInfo";
    /**
     * 设备状态任务id
     */
    public static final String DEVICE_STATUS_TASK_ID_KEY="deviceStatusTaskId";

    public static final String DEVICE_DATA_TASK_ID_KEY="deviceDataTaskId";
    /**
     * 控制器设备升级数据缓存key
     */
    public static final String CONTROLLER_DEVICE_UPGRADE_DATA_KEY="controllerDeviceUpgradeData";
    /**
     * 控制器设备升级状态检查任务id缓存key
     */
    public static final String CONTROLLER_UPGRADE_STATUS_CHECK_TASK_ID_KEY="controllerUpgradeStatusCheckTask";
    /**
     * 工程模式的数据缓存
     */
    public static final String ENGINEER_DATA_CACHE_KEY="engineer_data_cache:";

    /*com/lasercyber/lws/ui/bean/entity/ProcessParametersData.java  存储工艺库数据，非缓存 ，直接存储数据库。*/
    /**
     * modbus连接异常存储，用于检测是否可以下发数据
     */
    public static final String MODBUS_CONNECTED_ERROR_KEY="modbus_Connected_error";
    /**
     * 告警弹窗关闭时间key
     */
    public static final String WARN_DIALOG_CLOSE_TIME_KEY = "warnDialogCloseTime:";
    /**
     * 摄像头同步时间
     */
    public static final String CAMERA_ASYNC_TIME = "camera_async_time";
    /**
     * Normalized camera {@code appVersion} for Settings and remote {@code deviceInfo.cameraVersion}.
     */
    public static final String CAMERA_VERSION_DISPLAY = "camera_version_display";
    /** Camera ICMP ping reachability ({@code "1"} = reachable, {@code "0"} = unreachable). */
    public static final String CAMERA_PING_REACHABLE = "camera_ping_reachable";
    /**
     * 控制板升级失败回调
     */
    public static final String CONTROLLER_UPGRADE_ERROR_CALL_KEY = "controller_upgrade_error_call";
    /**
     * 工程师模式的上一次模式
     */
    public static final String ENGINEER_LAST_MODEL_KEY = "engineer_last_model";
    /**
     * 用户最近一次所在的顶层模式（快速模式 / 工程师模式），供 AI Vision 等界面展示。
     */
    public static final String LAST_TOP_MODE_CONTEXT_KEY = "last_top_mode_context";
    /** @see #LAST_TOP_MODE_CONTEXT_KEY */
    public static final int TOP_MODE_CONTEXT_QUICK = 1;
    /** @see #LAST_TOP_MODE_CONTEXT_KEY */
    public static final int TOP_MODE_CONTEXT_ENGINEER = 2;
    /**
     * 快速模式下，最近一次点击 End of work 时所在的工艺模式（用于 AI Vision Work Mode 快照显示）。
     */
    public static final String LAST_END_WORK_MODEL_QUICK_KEY = "last_end_work_model_quick";
    /**
     * 工程师模式下，最近一次点击 End of work 时所在的工艺模式（用于 AI Vision Work Mode 快照显示）。
     */
    public static final String LAST_END_WORK_MODEL_ENGINEER_KEY = "last_end_work_model_engineer";
    /**
     * 上传视频标记
     */
    public static final String UPLOADING_VIDEO_MARK = "uploading_video_mark";
}
