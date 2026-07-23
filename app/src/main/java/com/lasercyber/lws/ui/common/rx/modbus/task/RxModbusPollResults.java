package com.lasercyber.lws.ui.common.rx.modbus.task;

import android.util.Log;

import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.bean.entity.DeviceData;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.handler.GpioLedHandler;
import com.lasercyber.lws.ui.common.handler.WarnAlarmPipeline;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusDataReadHealth;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusStatusReadHealth;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusFiledConvert;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusReadFiled;
import com.lasercyber.lws.ui.common.utils.modbus.DataConvert;

import java.util.List;

/**
 * Applies chained device-status + device-data Modbus poll results to cache and side effects.
 */
final class RxModbusPollResults {

    private static final String TAG = LogTAGConstant.RxModbusPollResults;

    private RxModbusPollResults() {
    }

    static void applyDeviceStatus(List<ModbusReadFiled> statusFields) {
        boolean complete = !isSegmentTruncated(statusFields);
        ModbusStatusReadHealth.getInstance().recordOutcome(complete);

        DeviceStatus deviceStatus = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_STATUS_KEY);
        if (deviceStatus == null) {
            deviceStatus = new DeviceStatus();
        }
        if (complete) {
            deviceStatus = ModbusFiledConvert.deviceStatusConvert(statusFields, deviceStatus);
        }
        deviceStatus.setModbusStatusReadTruncated(ModbusStatusReadHealth.getInstance().isFault());
        MemoryCacheManager.getInstance().putSerializable(CacheKey.DEVICE_STATUS_KEY, deviceStatus);
        logPollSegment("status", statusFields, !complete);
    }

    static void applyDeviceStatusFailure(Throwable error) {
        Log.w(TAG, "device status poll failed", error);
        ModbusStatusReadHealth.getInstance().recordOutcome(false);

        DeviceStatus deviceStatus = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_STATUS_KEY);
        if (deviceStatus == null) {
            deviceStatus = new DeviceStatus();
        }
        deviceStatus.setModbusStatusReadTruncated(ModbusStatusReadHealth.getInstance().isFault());
        MemoryCacheManager.getInstance().putSerializable(CacheKey.DEVICE_STATUS_KEY, deviceStatus);
    }

    static void applyDeviceData(List<ModbusReadFiled> dataFields) {
        boolean complete = !isSegmentTruncated(dataFields);
        ModbusDataReadHealth.getInstance().recordOutcome(complete);

        DeviceData deviceData = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_DATA_KEY);
        if (deviceData == null) {
            deviceData = new DeviceData();
        }
        if (complete) {
            deviceData = ModbusFiledConvert.deviceDataConvert(dataFields, deviceData);
        }
        deviceData.setModbusDataReadTruncated(ModbusDataReadHealth.getInstance().isFault());
        MemoryCacheManager.getInstance().putSerializable(CacheKey.DEVICE_DATA_KEY, deviceData);
        logPollSegment("data", dataFields, !complete);
    }

    static void applyDeviceDataFailure(Throwable error) {
        Log.w(TAG, "device data poll failed", error);
        ModbusDataReadHealth.getInstance().recordOutcome(false);

        DeviceData deviceData = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_DATA_KEY);
        if (deviceData == null) {
            deviceData = new DeviceData();
        }
        deviceData.setModbusDataReadTruncated(ModbusDataReadHealth.getInstance().isFault());
        MemoryCacheManager.getInstance().putSerializable(CacheKey.DEVICE_DATA_KEY, deviceData);
    }

    static void finishPollCycle() {
        DeviceStatus deviceStatus = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_STATUS_KEY);
        if (deviceStatus == null) {
            return;
        }
        try {
            WarnAlarmPipeline.onModbusDeviceStatusPolled(deviceStatus, Utils.getApp());
        } catch (Exception exception) {
            Log.e(TAG, "告警日志/弹窗处理异常:" + exception.getMessage());
        }
        GpioLedHandler.ledHandler(deviceStatus);
    }

    private static void logPollSegment(String segment, List<ModbusReadFiled> fields, boolean truncated) {
        if (Log.isLoggable(TAG, Log.DEBUG)) {
            long present = fields.stream().filter(ModbusReadFiled::isValuePresent).count();
            Log.d(TAG, "poll " + segment + " present=" + present + "/" + fields.size()
                    + " truncated=" + truncated);
        }
    }

    static int countPresentFields(List<ModbusReadFiled> fields) {
        return (int) fields.stream().filter(ModbusReadFiled::isValuePresent).count();
    }

    static boolean isSegmentTruncated(List<ModbusReadFiled> fields) {
        return DataConvert.isTruncatedResponse(fields);
    }
}
