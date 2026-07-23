package com.lasercyber.lws.ui.common.constant;

/**
 * 固件升级的命令
 */
public class DeviceUpgradeConstant {
    /**
     * 固件信息
     */
    public static final short FIRMWARE_INFO = 0x1234;
    /**
     * 固件数据
     */
    public static final short FIRMWARE_DATA = 0x55AA;
    /**
     * 终止升级结果
     */
    public static final short FIRMWARE_END = 0x0000;
    /**
     * 请求固件信息
     */
    public static final int REQUEST_FIRMWARE_INFO = 0x1234;
    /**
     * 请求固件数据
     */
    public static final int REQUEST_FIRMWARE_DATA = 0x55AA;
    /**
     * 无效
     */
    public static final int UPGRADE_INVALID = 0x0000;
    /**
     * 升级成功
     */
    public static final int UPGRADE_SUCCESS = 0x1212;
    /**
     * 升级失败
     */
    public static final int UPGRADE_FAIL = 0x0202;
    /**
     * 控制器升级传输阶段上限（自下发固件信息起，首包未发出）
     */
    public static final long CONTROLLER_UPGRADE_TIMEOUT = 1000 * 60;
    /**
     * 已请求固件数据但长时间未成功下发任一包时视为卡住
     */
    public static final long CONTROLLER_UPGRADE_STALL_MS = 30_000;
    /**
     * 固件传输结束后，等待控制卡上报 {@link #UPGRADE_SUCCESS} 的最长时长。
     */
    public static final long CONTROLLER_UPGRADE_DEVICE_CONFIRM_TIMEOUT_MS = 120_000L;
    /**
     * Max firmware bytes per OTA data write frame ({@code OTA_ReqData[64 * 2]}).
     */
    public static final int FIRMWARE_PACKET_MAX_BYTES = 128;
    /**
     * 未找到升级文件
     */
    public static final int NOT_FOUND_UPGRADE_FILE_ERROR = 600;
    /**
     * 硬件版本不匹配
     */
    public static final int HARDWARE_VERSION_NOT_MATCH_ERROR = 601;
    /**
     * 软件版本不匹配
     */
    public static final int SOFTWARE_VERSION_NOT_MATCH_ERROR = 602;
    /**
     * 创建当前包升级数据异常
     */
    public static final int CREATE_CURRENT_PACKAGE_UPGRADE_DATA_ERROR = 603;
    /**
     * 升级失败
     */
    public static final int UPGRADE_FAIL_ERROR = 604;
    /**
     * 请求升级失败
     */
    public static final int REQUEST_UPGRADE_FAIL_ERROR = 605;
    /**
     * 版本相同，无需升级
     */
    public static final int VERSION_SAME_NOT_NEED_UPGRADE_ERROR = 606;
    /**
     * 设备长时间停留在同一固件偏移，重复请求同一包
     */
    public static final int FIRMWARE_OFFSET_STUCK_ERROR = 607;
}
