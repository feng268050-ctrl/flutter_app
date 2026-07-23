package com.lasercyber.lws.ui.bean.entity.dto;

import com.lasercyber.lws.ui.bean.entity.CommonSettings;
import com.lasercyber.lws.ui.bean.entity.DeviceData;
import com.lasercyber.lws.ui.bean.entity.DeviceInfo;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.bean.entity.StaticData;
import com.lasercyber.lws.ui.bean.entity.WarnTable;

import java.util.List;

import lombok.Data;

@Data
public class DeviceInfoVo {
    /*设备信息*/
    private Device device;

    /*设备自定义布局内容
    com/lasercyber/lws/ui/activitys/engineer/mode/model/StaticDataViewModel.java:38
    */
    private StaticData staticData;

    /*设备基础信息
    com/lasercyber/lws/ui/activitys/setting/fragment/DeviceInformationFragment.java:48
    * */
    private DeviceInfo deviceInfo;

    /*设备高级设置
    com/lasercyber/lws/ui/activitys/setting/model/AdvancedSettingViewModel.java:47
    * */
    private CommonSettings commonSettings;

    /*设备状态信息
  com/lasercyber/lws/ui/activitys/device/monitor/fragment/WarnInfoFragment.java:96
  * */
    private DeviceStatus deviceStatus;

    /*设备数据
    com/lasercyber/lws/ui/activitys/device/monitor/fragment/MachineStatusFragment.java:51
    * */
    private DeviceData deviceData;

    /*最新告警列表*/
    private List<WarnTable> warns;
}
