package com.lasercyber.lws.ui.common.utils.convert;

import com.lasercyber.lws.ui.bean.entity.AdvancedSettings;
import com.lasercyber.lws.ui.bean.entity.CommonSettings;
import com.lasercyber.lws.ui.bean.entity.ParameterSettings;
import com.lasercyber.lws.ui.bean.entity.vo.AdvancedSettingVo;
import com.lasercyber.lws.ui.common.constant.CommonSettingsLanguage;
import com.lasercyber.lws.ui.common.enums.UnitSystem;
import com.lasercyber.lws.ui.common.utils.DefaultValueUtils;

import org.junit.Assert;
import org.junit.Test;

public class AdvancedSettingConvertUtilTest {

    @Test
    public void convertToVo_includesAdvancedRegisterFields() {
        ParameterSettings parameter = new ParameterSettings();
        parameter.setInletGasPressureThreshold(101);
        parameter.setDriverTemperatureAlarmThreshold(72.5);
        parameter.setProtectiveLensTemperatureAlarmThreshold(73.5);
        parameter.setCollimatingLensTemperatureAlarmThreshold(66.5);
        parameter.setMotorTemperatureAlarmThreshold(74.5);
        parameter.setTemperatureAlarmRecoveryInterval(6.5);

        AdvancedSettingVo vo = AdvancedSettingConvertUtil.convertToVo(DefaultValueUtils.createDefaultCommonSettings(), parameter);

        Assert.assertEquals("101", vo.getInletGasPressureThreshold());
        Assert.assertEquals("72", vo.getDriverTemperatureAlarmThreshold());
        Assert.assertEquals("73", vo.getProtectiveLensTemperatureAlarmThreshold());
        Assert.assertEquals("66", vo.getCollimatingLensTemperatureAlarmThreshold());
        Assert.assertEquals("74", vo.getMotorTemperatureAlarmThreshold());
        Assert.assertEquals("6", vo.getTemperatureAlarmRecoveryInterval());
    }

    @Test
    public void convertToParameterSettings_includesAdvancedRegisterFields() {
        AdvancedSettingVo vo = new AdvancedSettingVo();
        vo.setInletGasPressureThreshold("102");
        vo.setDriverTemperatureAlarmThreshold("71");
        vo.setProtectiveLensTemperatureAlarmThreshold("72");
        vo.setCollimatingLensTemperatureAlarmThreshold("67");
        vo.setMotorTemperatureAlarmThreshold("73");
        vo.setTemperatureAlarmRecoveryInterval("7");

        ParameterSettings parameter = AdvancedSettingConvertUtil.convertToParameterSettings(vo);

        Assert.assertEquals(Integer.valueOf(102), parameter.getInletGasPressureThreshold());
        Assert.assertEquals(Double.valueOf(71), parameter.getDriverTemperatureAlarmThreshold());
        Assert.assertEquals(Double.valueOf(72), parameter.getProtectiveLensTemperatureAlarmThreshold());
        Assert.assertEquals(Double.valueOf(67), parameter.getCollimatingLensTemperatureAlarmThreshold());
        Assert.assertEquals(Double.valueOf(73), parameter.getMotorTemperatureAlarmThreshold());
        Assert.assertEquals(Double.valueOf(7), parameter.getTemperatureAlarmRecoveryInterval());
    }

    @Test
    public void defaultParameterSettings_hasAdvancedRegisterDefaults() {
        ParameterSettings settings = DefaultValueUtils.createDefaultParameterSettings();

        Assert.assertEquals(Integer.valueOf(0), settings.getInletGasPressureThreshold());
        Assert.assertEquals(Double.valueOf(70), settings.getDriverTemperatureAlarmThreshold());
        Assert.assertEquals(Double.valueOf(70), settings.getProtectiveLensTemperatureAlarmThreshold());
        Assert.assertEquals(Double.valueOf(65), settings.getCollimatingLensTemperatureAlarmThreshold());
        Assert.assertEquals(Double.valueOf(70), settings.getMotorTemperatureAlarmThreshold());
        Assert.assertEquals(Double.valueOf(5), settings.getTemperatureAlarmRecoveryInterval());
    }

    @Test
    public void convertToVo_includesAiAssistanceToggles() {
        AdvancedSettings advanced = DefaultValueUtils.createDefaultAdvancedSettings();
        advanced.setLensContaminationDetectionEnabled(false);
        advanced.setZeroPointOffsetDetectionEnabled(true);

        AdvancedSettingVo vo = AdvancedSettingConvertUtil.convertToVo(null, advanced);

        Assert.assertFalse(vo.getLensContaminationDetectionEnabled());
        Assert.assertTrue(vo.getZeroPointOffsetDetectionEnabled());
    }

    @Test
    public void convertToAdvancedSettings_roundTripsAiAssistanceToggles() {
        AdvancedSettingVo vo = new AdvancedSettingVo();
        vo.setLensContaminationDetectionEnabled(false);
        vo.setZeroPointOffsetDetectionEnabled(true);

        AdvancedSettings settings = AdvancedSettingConvertUtil.convertToAdvancedSettings(vo);

        Assert.assertFalse(settings.getLensContaminationDetectionEnabled());
        Assert.assertTrue(settings.getZeroPointOffsetDetectionEnabled());
    }

    @Test
    public void convertToVo_includesShowBootSelfCheck() {
        CommonSettings common = DefaultValueUtils.createDefaultCommonSettings();
        common.setShowBootSelfCheck(false);

        AdvancedSettingVo vo = AdvancedSettingConvertUtil.convertToVo(common, (AdvancedSettings) null);

        Assert.assertFalse(vo.getShowBootSelfCheck());
    }

    @Test
    public void convertToCommonSettings_mapsLanguageAndUnit() {
        AdvancedSettingVo vo = new AdvancedSettingVo();
        vo.setLanguageSetting("zh");
        vo.setUnitSetting(false);
        vo.setVoiceCheck(2);
        vo.setShowBootSelfCheck(false);

        CommonSettings common = AdvancedSettingConvertUtil.convertToCommonSettings(vo);

        Assert.assertEquals(CommonSettingsLanguage.ZH_CN, common.getLanguage());
        Assert.assertEquals(UnitSystem.IMPERIAL.getWireValue(), common.getUnit());
        Assert.assertEquals(Integer.valueOf(2), common.getSoundEffect());
        Assert.assertFalse(common.getShowBootSelfCheck());
    }
}
