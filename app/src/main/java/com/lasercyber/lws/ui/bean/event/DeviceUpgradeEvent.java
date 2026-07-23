package com.lasercyber.lws.ui.bean.event;

import com.lasercyber.lws.ui.common.enums.DeviceUpgradeEventTypeEnum;
import com.lasercyber.lws.ui.common.enums.UpgradeStatusEnum;

import java.io.Serializable;
import java.util.Date;

import lombok.Data;
import lombok.experimental.Accessors;

/**
 * 设备升级的事件
 */
@Accessors(chain = true)
@Data
public class DeviceUpgradeEvent implements Serializable {
    /**
     * 升级事件类型
     */
    private DeviceUpgradeEventTypeEnum eventType;
    /**
     * 升级结果
     */
    private UpgradeStatusEnum upgradeStatus;
    /**
     * 升级错误码
     */
    private Integer errorCode;
    /**
     * 升级开始时间
     **/
    private Date upgradeStartTime;
    /**
     * 升级结束时间
     **/
    private Date upgradeEndTime;

    /**
     * 创建控制器升级
     * @param upgradeStatus
     * @return
     */
    public static DeviceUpgradeEvent createControllerUpgradeEvent(UpgradeStatusEnum upgradeStatus) {
        DeviceUpgradeEvent deviceUpgradeEvent = new DeviceUpgradeEvent();
        deviceUpgradeEvent.setEventType(DeviceUpgradeEventTypeEnum.CONTROLLER_UPGRADE);
        deviceUpgradeEvent.setUpgradeStatus(upgradeStatus);
        deviceUpgradeEvent.setUpgradeEndTime(new Date());
        return deviceUpgradeEvent;
    }
}
