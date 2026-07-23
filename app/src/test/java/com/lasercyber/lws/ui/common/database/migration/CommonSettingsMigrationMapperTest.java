package com.lasercyber.lws.ui.common.database.migration;

import com.lasercyber.lws.ui.common.constant.CommonSettingsLanguage;
import com.lasercyber.lws.ui.common.enums.UnitSystem;

import org.junit.Assert;
import org.junit.Test;

public class CommonSettingsMigrationMapperTest {

    @Test
    public void mapLanguage_zhVariants() {
        Assert.assertEquals(CommonSettingsLanguage.ZH_CN, CommonSettingsMigrationMapper.mapLanguage("zh"));
        Assert.assertEquals(CommonSettingsLanguage.ZH_CN, CommonSettingsMigrationMapper.mapLanguage("zh-CN"));
    }

    @Test
    public void mapLanguage_defaultsToEnUs() {
        Assert.assertEquals(CommonSettingsLanguage.EN_US, CommonSettingsMigrationMapper.mapLanguage("en"));
        Assert.assertEquals(CommonSettingsLanguage.EN_US, CommonSettingsMigrationMapper.mapLanguage(null));
    }

    @Test
    public void mapUnit_legacyBoolean() {
        Assert.assertEquals(UnitSystem.IMPERIAL.getWireValue(), CommonSettingsMigrationMapper.mapUnit(0));
        Assert.assertEquals(UnitSystem.METRIC.getWireValue(), CommonSettingsMigrationMapper.mapUnit(1));
        Assert.assertEquals(UnitSystem.METRIC.getWireValue(), CommonSettingsMigrationMapper.mapUnit(null));
    }
}
