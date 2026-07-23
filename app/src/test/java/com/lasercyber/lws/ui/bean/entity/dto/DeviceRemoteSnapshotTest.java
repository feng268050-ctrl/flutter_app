package com.lasercyber.lws.ui.bean.entity.dto;

import com.blankj.utilcode.util.GsonUtils;
import com.lasercyber.lws.ui.bean.entity.CommonSettings;
import com.lasercyber.lws.ui.common.constant.CommonSettingsLanguage;
import com.lasercyber.lws.ui.common.enums.UnitSystem;

import org.junit.Assert;
import org.junit.Test;

public class DeviceRemoteSnapshotTest {

    @Test
    public void gson_serializesCommonSettings_notAdvancedSettings() {
        CommonSettings common = new CommonSettings();
        common.setLanguage(CommonSettingsLanguage.ZH_CN);
        common.setUnit(UnitSystem.METRIC.getWireValue());
        common.setSoundEffect(1);
        common.setShowBootSelfCheck(true);
        common.setShowSafetyGroundLockAlarm(false);

        DeviceRemoteSnapshot snapshot = new DeviceRemoteSnapshot();
        snapshot.setCommonSettings(common);

        String json = GsonUtils.toJson(snapshot);

        Assert.assertTrue(json.contains("\"commonSettings\""));
        Assert.assertTrue(json.contains("\"language\":\"zh-CN\""));
        Assert.assertTrue(json.contains("\"showSafetyGroundLockAlarm\":false"));
        Assert.assertFalse(json.contains("advancedSettings"));
    }
}
