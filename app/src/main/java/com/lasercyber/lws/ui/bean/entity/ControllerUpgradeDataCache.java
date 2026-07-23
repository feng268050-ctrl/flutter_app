package com.lasercyber.lws.ui.bean.entity;

import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusHexData;
import com.lasercyber.lws.ui.common.utils.UpgradeFileReaderUtils;

import java.io.File;
import java.io.Serializable;
import java.util.Date;
import java.util.HashMap;
import java.util.LinkedList;
import java.util.List;

import lombok.Data;

/**
 * 控制器升级数据缓存
 */
@Data
public class ControllerUpgradeDataCache implements Serializable {
    /**
     * 硬件版本
     */
    private Integer fileHardwareVersion;
    /**
     * 软件版本
     */
    private Integer fileSoftwareVersion;
    /**
     * 开始升级时间
     */
    private Date createTime;
    /**
     * 最近一次成功下发固件数据包的时间（用于检测传输卡住）。
     */
    private long lastPacketSentAtMs;
    /**
     * 已下发的固件偏移；设备未换偏移前不再重复写同一包。
     */
    private int lastSentOffset = -1;
    private Integer lastSentLength;
    private long lastSentOffsetAtMs;
    /**
     * 固件数据已全部下发且 FIRMWARE_END 已写；等待设备 {@code otaUpgradeCmd} 确认。
     */
    private boolean awaitingDeviceConfirm;
    private long transferCompletedAtMs;
    private volatile boolean confirmPollInFlight;
    /**
     * 升级文件信息
     */
    private File file;
    /**
     * 基础文件信息字段
     */
    private LinkedList<ModbusHexData> baseFileDataFiled;

    /**
     * 读取文件的数据
     * @param offsetAddress
     * @param length
     * @return
     */
    public byte[] readFileData(int offsetAddress,int length){
        return UpgradeFileReaderUtils.readRangeBytes(file,offsetAddress,length);
    }

    /**
     * 初始化缓存
     * @param file 固件对象
     * @param baseFileDataFiled 基础的固件信息字段
     * @return 缓存对象
     */
    public static ControllerUpgradeDataCache init(File file, LinkedList<ModbusHexData> baseFileDataFiled){
        ControllerUpgradeDataCache controllerUpgradeDataCache = new ControllerUpgradeDataCache();
        controllerUpgradeDataCache.file = file;
        controllerUpgradeDataCache.fileHardwareVersion = UpgradeFileReaderUtils.getFileHardwareVersion(file.getName());
        controllerUpgradeDataCache.fileSoftwareVersion = UpgradeFileReaderUtils.getFileSoftwareVersion(file.getName());
        controllerUpgradeDataCache.createTime = new Date();
        controllerUpgradeDataCache.baseFileDataFiled = baseFileDataFiled;
        return controllerUpgradeDataCache;

    }
}
