package com.lasercyber.lws.ui.common.utils.convert;

import com.blankj.utilcode.util.StringUtils;
import com.lasercyber.lws.ui.bean.entity.AdvancedSettings;
import com.lasercyber.lws.ui.bean.entity.CommonSettings;
import com.lasercyber.lws.ui.bean.entity.ParameterSettings;
import com.lasercyber.lws.ui.bean.entity.vo.AdvancedSettingVo;
import com.lasercyber.lws.ui.common.constant.CommonSettingsLanguage;
import com.lasercyber.lws.ui.common.enums.UnitSystem;

/**
 * Merges {@link CommonSettings} and Advanced Settings parameters with {@link AdvancedSettingVo} for UI binding.
 */
public class AdvancedSettingConvertUtil {

    public static AdvancedSettingVo convertToVo(CommonSettings common, AdvancedSettings advancedSettings) {
        if (common == null && advancedSettings == null) {
            return null;
        }
        AdvancedSettingVo vo = new AdvancedSettingVo();
        if (advancedSettings != null) {
            vo.setId(advancedSettings.getId());
            vo.setZeroPointCorrection(convertDoubleToString(advancedSettings.getZeroPointCorrection()));
            vo.setProperSwingWidth(convertDoubleToString(advancedSettings.getProperSwingWidth()));
            vo.setLaserStartPower(convertDoubleToString(advancedSettings.getLaserStartPower()));
            vo.setLaserEndPower(convertDoubleToString(advancedSettings.getLaserEndPower()));
            vo.setBlowPressureThreshold(convertDoubleToString(advancedSettings.getBlowPressureThreshold()));
            vo.setRedLightOffset(advancedSettings.getRedLightOffset() != null ? String.valueOf(advancedSettings.getRedLightOffset()) : "");
            vo.setSwingSpeedUpperLimit(advancedSettings.getSwingSpeedUpperLimit() != null ? String.valueOf(advancedSettings.getSwingSpeedUpperLimit()) : "");
            vo.setSwingSpeedLowerLimit(advancedSettings.getSwingSpeedLowerLimit() != null ? String.valueOf(advancedSettings.getSwingSpeedLowerLimit()) : "");
            vo.setManualDrawStringSpeed(advancedSettings.getManualDrawStringSpeed() != null ? String.valueOf(advancedSettings.getManualDrawStringSpeed()) : "");
            vo.setManualWireFeedSpeed(advancedSettings.getManualWireFeedSpeed() != null ? String.valueOf(advancedSettings.getManualWireFeedSpeed()) : "");
            vo.setInletGasPressureThreshold(advancedSettings.getInletGasPressureThreshold() != null ? String.valueOf(advancedSettings.getInletGasPressureThreshold()) : "");
            vo.setDriverTemperatureAlarmThreshold(convertDoubleToString(advancedSettings.getDriverTemperatureAlarmThreshold()));
            vo.setProtectiveLensTemperatureAlarmThreshold(convertDoubleToString(advancedSettings.getProtectiveLensTemperatureAlarmThreshold()));
            vo.setCollimatingLensTemperatureAlarmThreshold(convertDoubleToString(advancedSettings.getCollimatingLensTemperatureAlarmThreshold()));
            vo.setMotorTemperatureAlarmThreshold(convertDoubleToString(advancedSettings.getMotorTemperatureAlarmThreshold()));
            vo.setTemperatureAlarmRecoveryInterval(convertDoubleToString(advancedSettings.getTemperatureAlarmRecoveryInterval()));
            vo.setLensContaminationDetectionEnabled(
                    advancedSettings.getLensContaminationDetectionEnabled() == null
                            || advancedSettings.getLensContaminationDetectionEnabled());
            vo.setZeroPointOffsetDetectionEnabled(
                    advancedSettings.getZeroPointOffsetDetectionEnabled() == null
                            || advancedSettings.getZeroPointOffsetDetectionEnabled());
            vo.setKeepLaserOnWhileAlarmed(
                    Boolean.TRUE.equals(advancedSettings.getKeepLaserOnWhileAlarmed()));
            vo.setAllowWorkAfterCameraAlarm(
                    Boolean.TRUE.equals(advancedSettings.getAllowWorkAfterCameraAlarm()));
            vo.setAllowWorkAfterGasAlarm(
                    Boolean.TRUE.equals(advancedSettings.getAllowWorkAfterGasAlarm()));
            vo.setAllowWorkAfterLensContamination(
                    Boolean.TRUE.equals(advancedSettings.getAllowWorkAfterLensContamination()));
            vo.setAllowWorkAfterFeederAlarm(
                    Boolean.TRUE.equals(advancedSettings.getAllowWorkAfterFeederAlarm()));
        }
        applyCommonSettings(vo, common);
        return vo;
    }

    public static AdvancedSettingVo convertToVo(CommonSettings common, ParameterSettings parameter) {
        if (common == null && parameter == null) {
            return null;
        }
        AdvancedSettingVo vo = new AdvancedSettingVo();
        if (parameter != null) {
            vo.setId(parameter.getId());
            vo.setZeroPointCorrection(convertDoubleToString(parameter.getZeroPointCorrection()));
            vo.setProperSwingWidth(convertDoubleToString(parameter.getProperSwingWidth()));
            vo.setLaserStartPower(convertDoubleToString(parameter.getLaserStartPower()));
            vo.setLaserEndPower(convertDoubleToString(parameter.getLaserEndPower()));
            vo.setBlowPressureThreshold(convertDoubleToString(parameter.getBlowPressureThreshold()));
            vo.setRedLightOffset(parameter.getRedLightOffset() != null ? String.valueOf(parameter.getRedLightOffset()) : "");
            vo.setSwingSpeedUpperLimit(parameter.getSwingSpeedUpperLimit() != null ? String.valueOf(parameter.getSwingSpeedUpperLimit()) : "");
            vo.setSwingSpeedLowerLimit(parameter.getSwingSpeedLowerLimit() != null ? String.valueOf(parameter.getSwingSpeedLowerLimit()) : "");
            vo.setManualDrawStringSpeed(parameter.getManualDrawStringSpeed() != null ? String.valueOf(parameter.getManualDrawStringSpeed()) : "");
            vo.setManualWireFeedSpeed(parameter.getManualWireFeedSpeed() != null ? String.valueOf(parameter.getManualWireFeedSpeed()) : "");
            vo.setInletGasPressureThreshold(parameter.getInletGasPressureThreshold() != null ? String.valueOf(parameter.getInletGasPressureThreshold()) : "");
            vo.setDriverTemperatureAlarmThreshold(convertDoubleToString(parameter.getDriverTemperatureAlarmThreshold()));
            vo.setProtectiveLensTemperatureAlarmThreshold(convertDoubleToString(parameter.getProtectiveLensTemperatureAlarmThreshold()));
            vo.setCollimatingLensTemperatureAlarmThreshold(convertDoubleToString(parameter.getCollimatingLensTemperatureAlarmThreshold()));
            vo.setMotorTemperatureAlarmThreshold(convertDoubleToString(parameter.getMotorTemperatureAlarmThreshold()));
            vo.setTemperatureAlarmRecoveryInterval(convertDoubleToString(parameter.getTemperatureAlarmRecoveryInterval()));
        }
        applyCommonSettings(vo, common);
        return vo;
    }

    public static CommonSettings convertToCommonSettings(AdvancedSettingVo vo) {
        if (vo == null) {
            return null;
        }
        CommonSettings settings = new CommonSettings();
        String language = vo.getLanguageSetting();
        settings.setLanguage(CommonSettingsLanguage.fromLegacyLanguageSetting(language));
        settings.setUnit(UnitSystem.fromLegacyUnitSetting(vo.getUnitSetting()).getWireValue());
        settings.setSoundEffect(vo.getVoiceCheck() == null ? 0 : vo.getVoiceCheck());
        settings.setShowBootSelfCheck(vo.getShowBootSelfCheck() == null || vo.getShowBootSelfCheck());
        return settings;
    }

    public static ParameterSettings convertToParameterSettings(AdvancedSettingVo vo) {
        if (vo == null) {
            return null;
        }
        ParameterSettings settings = new ParameterSettings();
        settings.setId(vo.getId());
        settings.setZeroPointCorrection(convertStringToDouble(vo.getZeroPointCorrection()));
        settings.setProperSwingWidth(convertStringToDouble(vo.getProperSwingWidth()));
        settings.setLaserStartPower(convertStringToDouble(vo.getLaserStartPower()));
        settings.setLaserEndPower(convertStringToDouble(vo.getLaserEndPower()));
        settings.setBlowPressureThreshold(convertStringToDouble(vo.getBlowPressureThreshold()));
        settings.setRedLightOffset(!StringUtils.isEmpty(vo.getRedLightOffset()) ? Integer.parseInt(vo.getRedLightOffset()) : null);
        settings.setSwingSpeedUpperLimit(!StringUtils.isEmpty(vo.getSwingSpeedUpperLimit()) ? Integer.parseInt(vo.getSwingSpeedUpperLimit()) : null);
        settings.setSwingSpeedLowerLimit(!StringUtils.isEmpty(vo.getSwingSpeedLowerLimit()) ? Integer.parseInt(vo.getSwingSpeedLowerLimit()) : null);
        settings.setManualDrawStringSpeed(!StringUtils.isEmpty(vo.getManualDrawStringSpeed()) ? Integer.parseInt(vo.getManualDrawStringSpeed()) : null);
        settings.setManualWireFeedSpeed(!StringUtils.isEmpty(vo.getManualWireFeedSpeed()) ? Integer.parseInt(vo.getManualWireFeedSpeed()) : null);
        settings.setInletGasPressureThreshold(!StringUtils.isEmpty(vo.getInletGasPressureThreshold()) ? Integer.parseInt(vo.getInletGasPressureThreshold()) : null);
        settings.setDriverTemperatureAlarmThreshold(convertStringToDouble(vo.getDriverTemperatureAlarmThreshold()));
        settings.setProtectiveLensTemperatureAlarmThreshold(convertStringToDouble(vo.getProtectiveLensTemperatureAlarmThreshold()));
        settings.setCollimatingLensTemperatureAlarmThreshold(convertStringToDouble(vo.getCollimatingLensTemperatureAlarmThreshold()));
        settings.setMotorTemperatureAlarmThreshold(convertStringToDouble(vo.getMotorTemperatureAlarmThreshold()));
        settings.setTemperatureAlarmRecoveryInterval(convertStringToDouble(vo.getTemperatureAlarmRecoveryInterval()));
        return settings;
    }

    public static AdvancedSettings convertToAdvancedSettings(AdvancedSettingVo vo) {
        if (vo == null) {
            return null;
        }
        AdvancedSettings settings = new AdvancedSettings();
        settings.setId(vo.getId());
        settings.setZeroPointCorrection(convertStringToDouble(vo.getZeroPointCorrection()));
        settings.setProperSwingWidth(convertStringToDouble(vo.getProperSwingWidth()));
        settings.setLaserStartPower(convertStringToDouble(vo.getLaserStartPower()));
        settings.setLaserEndPower(convertStringToDouble(vo.getLaserEndPower()));
        settings.setBlowPressureThreshold(convertStringToDouble(vo.getBlowPressureThreshold()));
        settings.setRedLightOffset(!StringUtils.isEmpty(vo.getRedLightOffset()) ? Integer.parseInt(vo.getRedLightOffset()) : null);
        settings.setSwingSpeedUpperLimit(!StringUtils.isEmpty(vo.getSwingSpeedUpperLimit()) ? Integer.parseInt(vo.getSwingSpeedUpperLimit()) : null);
        settings.setSwingSpeedLowerLimit(!StringUtils.isEmpty(vo.getSwingSpeedLowerLimit()) ? Integer.parseInt(vo.getSwingSpeedLowerLimit()) : null);
        settings.setManualDrawStringSpeed(!StringUtils.isEmpty(vo.getManualDrawStringSpeed()) ? Integer.parseInt(vo.getManualDrawStringSpeed()) : null);
        settings.setManualWireFeedSpeed(!StringUtils.isEmpty(vo.getManualWireFeedSpeed()) ? Integer.parseInt(vo.getManualWireFeedSpeed()) : null);
        settings.setInletGasPressureThreshold(!StringUtils.isEmpty(vo.getInletGasPressureThreshold()) ? Integer.parseInt(vo.getInletGasPressureThreshold()) : null);
        settings.setDriverTemperatureAlarmThreshold(convertStringToDouble(vo.getDriverTemperatureAlarmThreshold()));
        settings.setProtectiveLensTemperatureAlarmThreshold(convertStringToDouble(vo.getProtectiveLensTemperatureAlarmThreshold()));
        settings.setCollimatingLensTemperatureAlarmThreshold(convertStringToDouble(vo.getCollimatingLensTemperatureAlarmThreshold()));
        settings.setMotorTemperatureAlarmThreshold(convertStringToDouble(vo.getMotorTemperatureAlarmThreshold()));
        settings.setTemperatureAlarmRecoveryInterval(convertStringToDouble(vo.getTemperatureAlarmRecoveryInterval()));
        settings.setLensContaminationDetectionEnabled(
                vo.getLensContaminationDetectionEnabled() == null || vo.getLensContaminationDetectionEnabled());
        settings.setZeroPointOffsetDetectionEnabled(
                vo.getZeroPointOffsetDetectionEnabled() == null || vo.getZeroPointOffsetDetectionEnabled());
        settings.setKeepLaserOnWhileAlarmed(
                Boolean.TRUE.equals(vo.getKeepLaserOnWhileAlarmed()));
        settings.setAllowWorkAfterCameraAlarm(
                Boolean.TRUE.equals(vo.getAllowWorkAfterCameraAlarm()));
        settings.setAllowWorkAfterGasAlarm(
                Boolean.TRUE.equals(vo.getAllowWorkAfterGasAlarm()));
        settings.setAllowWorkAfterLensContamination(
                Boolean.TRUE.equals(vo.getAllowWorkAfterLensContamination()));
        settings.setAllowWorkAfterFeederAlarm(
                Boolean.TRUE.equals(vo.getAllowWorkAfterFeederAlarm()));
        return settings;
    }

    private static void applyCommonSettings(AdvancedSettingVo vo, CommonSettings common) {
        if (vo == null || common == null) {
            return;
        }
        vo.setLanguageSetting(common.getLanguage() != null ? common.getLanguage() : CommonSettingsLanguage.EN_US);
        vo.setUnitSetting(UnitSystem.fromWireValue(common.getUnit()).toLegacyUnitSetting());
        vo.setVoiceCheck(common.getSoundEffect() != null ? common.getSoundEffect() : 0);
        vo.setShowBootSelfCheck(common.getShowBootSelfCheck() == null || common.getShowBootSelfCheck());
    }

    private static String convertDoubleToString(Double value) {
        return value != null ? String.valueOf(value) : "";
    }

    private static Double convertStringToDouble(String value) {
        if (value == null || value.trim().isEmpty()) {
            return null;
        }
        try {
            return Double.parseDouble(value.trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }
}
