package com.lasercyber.lws.ui.bean.entity.dto;

import com.lasercyber.lws.ui.bean.entity.CommonSettings;
import com.lasercyber.lws.ui.bean.entity.DeviceData;
import com.lasercyber.lws.ui.bean.entity.DeviceInfo;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.bean.entity.StaticData;
import com.lasercyber.lws.ui.bean.entity.WarnTable;

import java.io.Serializable;
import java.util.List;

import lombok.Data;

/**
 * Transport-neutral aggregate of device-side state for remote inspection (e.g. WebSocket
 * {@code command.stat_response} {@code data}). Intentionally excludes a top-level {@code device}
 * identity blob; connection-bound identity is used instead.
 */
@Data
public class DeviceRemoteSnapshot implements Serializable {
    private StaticData staticData;
    private DeviceInfo deviceInfo;
    private CommonSettings commonSettings;
    private DeviceStatus deviceStatus;
    private DeviceData deviceData;
    private ProcessParametersData processParameters;
    private List<WarnTable> warns;
    /** Server-driven remote lock; only cleared by {@code command.unlock}. */
    private Boolean isLocked;
    /** Connected Wi-Fi metadata; {@code null} when not on Wi-Fi with a usable LAN address. */
    private ConnectedWifiInfo wifiInfo;

    public static DeviceRemoteSnapshot fromDeviceInfoVo(DeviceInfoVo source) {
        DeviceRemoteSnapshot out = new DeviceRemoteSnapshot();
        if (source == null) {
            return out;
        }
        out.setStaticData(source.getStaticData());
        out.setDeviceInfo(source.getDeviceInfo());
        out.setCommonSettings(source.getCommonSettings());
        out.setDeviceStatus(source.getDeviceStatus());
        out.setDeviceData(source.getDeviceData());
        out.setWarns(source.getWarns());
        return out;
    }
}
