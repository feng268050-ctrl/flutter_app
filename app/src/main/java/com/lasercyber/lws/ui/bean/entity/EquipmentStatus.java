package com.lasercyber.lws.ui.bean.entity;

import com.lasercyber.lws.ui.bean.ui.DataEquals;

import java.io.Serializable;

import lombok.Data;

/**
 * 状态栏显示信息
 */
@Data
public class EquipmentStatus implements Serializable, DataEquals<EquipmentStatus> {
    // 设备状态字段
    @Deprecated
    private boolean isGunSwitchOn;      // 枪头开关导通
    @Deprecated
    private boolean isSafetyLockOn;     // 安全地锁导通
    @Deprecated
    private boolean isVentOn;           // 通气状态
    @Deprecated
    private boolean isEmergencyStop;    // 急停状态
    private boolean isNetworkConnected; // 网络连接
    private boolean isBluetoothConnected; // 蓝牙连接

    /*显示连接情况*/
    private boolean isContent = true;
    @Override
    public boolean dataChange(EquipmentStatus data) {
        // 1. 空指针检查：如果传入的 data 是 null，没有可比较的，视为没有变化。
        if (data == null) {
            return false;
        }

        // 2. 自身比较：如果是同一个对象，数据必然相同。
        if (this == data) {
            return false;
        }

        // 3. 逐一比较所有字段。
        //    只要有一个字段的值不相等，就说明数据发生了变化，立即返回 true。
        if (this.isGunSwitchOn != data.isGunSwitchOn) {
            return true;
        }
        if (this.isSafetyLockOn != data.isSafetyLockOn) {
            return true;
        }
        if (this.isVentOn != data.isVentOn) {
            return true;
        }
        if (this.isEmergencyStop != data.isEmergencyStop) {
            return true;
        }
        if (this.isNetworkConnected != data.isNetworkConnected) {
            return true;
        }
        if (this.isBluetoothConnected != data.isBluetoothConnected) {
            return true;
        }

        // 4. 如果所有字段都比较完毕且都相等，则说明数据没有变化。
        return false;
    }
}
