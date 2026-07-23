package com.lasercyber.lws.ui.activitys.engineer.mode.model;

import androidx.lifecycle.LifecycleOwner;
import androidx.lifecycle.LiveData;
import androidx.lifecycle.MutableLiveData;
import androidx.lifecycle.Transformations;
import androidx.lifecycle.ViewModel;

import com.blankj.utilcode.util.StringUtils;
import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.bean.entity.AdvancedSettings;
import com.lasercyber.lws.ui.bean.entity.CommonSettings;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.enums.UnitSystem;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.common.enums.MaterialTypeEnum;
import com.lasercyber.lws.ui.common.utils.InchMillimeterUtils;
import com.lasercyber.lws.ui.common.utils.EngineerCommonlyUsedParameterNaming;
import com.lasercyber.lws.ui.common.utils.MaterialDisplayNameUtils;
import com.lasercyber.lws.ui.common.utils.ProcessParameterDisplayFormat;
import com.lasercyber.lws.ui.common.utils.convert.EngineerWashConvert;

import java.util.Objects;

import lombok.Getter;

public abstract class BaseProcessParametersDataViewModel extends ViewModel {
    @Getter
    protected LiveData<AdvancedSettings> parameterSettingsLiveData;
    protected LiveData<CommonSettings> commonSettingsLiveData;
    private LiveData<Boolean> useMMUnitLiveData;
    // 点焊间隔

    public String getPointWeldingInterval() {
        ProcessParametersData value = getDataProxy();
        if (value == null || value.getPointWeldingInterval() == null) {
            return "";
        }
        return ProcessParameterDisplayFormat.asInteger(value.getPointWeldingInterval());
    }

    // 点焊持续

    public String getPointWeldingDuration() {
        ProcessParametersData value = getDataProxy();
        if (value == null || value.getPointWeldingDuration() == null) {
            return "";
        }
        return ProcessParameterDisplayFormat.asInteger(value.getPointWeldingDuration());
    }


    // 摆动频率

    public String getSwingFrequency() {
        ProcessParametersData value = getDataProxy();
        if (value == null || value.getSwingFrequency() == null) {
            return "";
        }
        return ProcessParameterDisplayFormat.asInteger(value.getSwingFrequency());
    }


    // 关光延时

    public String getCloseLightDelay() {
        ProcessParametersData value = getDataProxy();
        if (value == null || value.getCloseLightDelay() == null) {
            return "";
        }
        return ProcessParameterDisplayFormat.asInteger(value.getCloseLightDelay());
    }

    // 吹气延时

    public String getBlowDelay() {
        ProcessParametersData value = getDataProxy();
        if (value == null || value.getBlowDelay() == null) {
            return "";
        }
        return ProcessParameterDisplayFormat.asInteger(value.getBlowDelay());
    }

    // 关气延时

    public String getCloseAirDelay() {
        ProcessParametersData value = getDataProxy();
        if (value == null || value.getCloseAirDelay() == null) {
            return "";
        }
        return ProcessParameterDisplayFormat.asInteger(value.getCloseAirDelay());
    }

    /**
     * 材料展示文案（用于弹窗等 UI）
     */
    public String getMaterialTypeLabel() {
        ProcessParametersData value = getDataProxy();
        if (value == null || value.getMaterialType() == null) {
            return "";
        }
        if (isCustomMaterialType() && !StringUtils.isEmpty(value.getMaterialName())) {
            return value.getMaterialName();
        }
        String text = EngineerWashConvert.convertCleaningMaterialsText(value.getMaterialType());
        if (StringUtils.isEmpty(text)) {
            return "";
        }
        return text;
    }

    /**
     * 是否自定义材质
     *
     * @return
     */
    public boolean isCustomMaterialType() {
        ProcessParametersData value = getDataProxy();
        if (value == null) {
            return false;
        }
        return Objects.equals(value.getMaterialType(), MaterialTypeEnum.CUSTOMIZE.getType());
    }

    /**
     * 摆动宽度
     *
     * @return
     */
    public String getSwingWidth() {
        ProcessParametersData value = getDataProxy();
        if (value == null || value.getSwingWidth() == null) {
            return "";
        }
        if (!useMMUnit()) {
            return InchMillimeterUtils.mmToInStr(value.getSwingWidth());
        }
        return ProcessParameterDisplayFormat.asDecimal(value.getSwingWidth());
    }


    /**
     * 激光功率
     *
     * @return
     */
    public String getLaserPower() {
        ProcessParametersData value = getDataProxy();
        if (value == null || value.getLaserPower() == null) {
            return "";
        }
        return ProcessParameterDisplayFormat.asInteger(value.getLaserPower());
    }

    /**
     * 获取厚度
     */
    public String getThickness() {
        ProcessParametersData value = getDataProxy();
        if (value == null || value.getThickness() == null) {
            return "";
        }
        Double thickness = value.getThickness();
        if (!useMMUnit()) {
            return InchMillimeterUtils.mmToInStr(thickness);
        }
        return ProcessParameterDisplayFormat.asDecimal(thickness);
    }


    /**
     * laserFrequency 激光频率
     */
    public String getLaserFrequency() {
        ProcessParametersData value = getDataProxy();
        if (value == null || value.getLaserFrequency() == null) {
            return "";
        }
        return ProcessParameterDisplayFormat.asInteger(value.getLaserFrequency());
    }


    /**
     * laserDutyCycle 激光占空比
     */
    public String getLaserDutyCycle() {
        ProcessParametersData value = getDataProxy();
        if (value == null || value.getLaserDutyCycle() == null) {
            return "";
        }
        return ProcessParameterDisplayFormat.asInteger(value.getLaserDutyCycle());
    }


    /**
     * perforationFrequency  穿孔频率
     */
    public String getPerforationFrequency() {
        ProcessParametersData value = getDataProxy();
        if (value == null || value.getPerforationFrequency() == null) {
            return "";
        }
        return ProcessParameterDisplayFormat.asInteger(value.getPerforationFrequency());
    }

    /**
     * perforationDuration  穿孔时长
     */
    public String getPerforationDuration() {
        ProcessParametersData value = getDataProxy();
        if (value == null || value.getPerforationDuration() == null) {
            return "";
        }
        return ProcessParameterDisplayFormat.asDecimal(value.getPerforationDuration());
    }


    /**
     * retractLength 退拉长度
     */
    public String getRetractLength() {
        ProcessParametersData value = getDataProxy();
        if (value == null || value.getRetractLength() == null) {
            return "";
        }
        if (!useMMUnit()) {
            return InchMillimeterUtils.mmToInStr(value.getRetractLength());
        }
        return ProcessParameterDisplayFormat.asDecimal(value.getRetractLength());
    }


    /**
     * retractSpeed 退拉速度
     */
    public String getRetractSpeed() {
        ProcessParametersData value = getDataProxy();
        if (value == null || value.getRetractSpeed() == null) {
            return "";
        }
        if (!useMMUnit()) {
            return ProcessParameterDisplayFormat.asDecimal(
                    InchMillimeterUtils.mmToInPerSecond(value.getRetractSpeed()));
        }
        return ProcessParameterDisplayFormat.asInteger(value.getRetractSpeed());
    }

    /**
     * fillLength 补丝长度
     */
    public String getFillLength() {
        ProcessParametersData value = getDataProxy();
        if (value == null || value.getFillLength() == null) {
            return "";
        }
        if (!useMMUnit()) {
            return InchMillimeterUtils.mmToInStr(value.getFillLength());
        }
        return ProcessParameterDisplayFormat.asDecimal(value.getFillLength());
    }


    /**
     * fillDelay 补丝时延
     */
    public String getFillDelay() {
        ProcessParametersData value = getDataProxy();
        if (value == null || value.getFillDelay() == null) {
            return "";
        }
        return ProcessParameterDisplayFormat.asInteger(value.getFillDelay());
    }


    /**
     * powerRampUp  功率缓升
     *
     * @return
     */
    public String getPowerRampUp() {
        ProcessParametersData value = getDataProxy();
        if (value == null || value.getPowerRampUp() == null) {
            return "";
        }
        return ProcessParameterDisplayFormat.asInteger(value.getPowerRampUp());
    }


    /**
     * powerRampDown  功率缓降
     *
     * @return
     */
    public String getPowerRampDown() {
        ProcessParametersData value = getDataProxy();
        if (value == null || value.getPowerRampDown() == null) {
            return "";
        }
        return ProcessParameterDisplayFormat.asInteger(value.getPowerRampDown());
    }


    /**
     * wireFeedSpeed  送丝速度
     *
     * @return
     */
    public String getWireFeedSpeed() {
        ProcessParametersData value = getDataProxy();
        if (value == null || value.getWireFeedSpeed() == null) {
            return "";
        }
        if (!useMMUnit()) {
            return ProcessParameterDisplayFormat.asDecimal(
                    InchMillimeterUtils.mmToInPerSecond(value.getWireFeedSpeed()));
        }
        return ProcessParameterDisplayFormat.asInteger(value.getWireFeedSpeed());
    }


    /**
     * 送丝时延
     */
    public String getWireFeedingDelay() {
        ProcessParametersData value = getDataProxy();
        if (value == null || value.getWireFeedingDelay() == null) {
            return "";
        }
        return ProcessParameterDisplayFormat.asInteger(value.getWireFeedingDelay());
    }


    /**
     * perforationPower 穿孔功率
     */
    public String getPerforationPower() {
        ProcessParametersData value = getDataProxy();
        if (value == null || value.getPerforationPower() == null) {
            return "";
        }
        return ProcessParameterDisplayFormat.asInteger(value.getPerforationPower());
    }


    /**
     * 穿孔占空比
     */
    public String getPerforationDutyCycle() {
        ProcessParametersData value = getDataProxy();
        if (value == null || value.getPerforationDutyCycle() == null) {
            return "";
        }
        return ProcessParameterDisplayFormat.asInteger(value.getPerforationDutyCycle());
    }


    /**
     * 获取名称
     */
    public String getName() {
        ProcessParametersData value = getDataProxy();
        if (value == null || value.getName() == null) {
            return "";
        }
        return MaterialDisplayNameUtils.localizeKnownMaterialName(value.getName(), value.getMaterialType());
    }

    /**
     * Save as Common 对话框默认名称：材质显示名-厚度显示值（含单位）；清洗模式仅材质显示名。
     */
    public String getSuggestedCommonlyUsedParameterName() {
        return EngineerCommonlyUsedParameterNaming.forSaveAsCommon(
                getMaterialTypeLabel(),
                getDataProxy(),
                Boolean.TRUE.equals(useMMUnit())
        );
    }

    public abstract ProcessParametersData getDataProxy();

    protected void initUseMMUnitLiveData() {
        if (commonSettingsLiveData == null) {
            useMMUnitLiveData = new MutableLiveData<>(true);
            return;
        }
        useMMUnitLiveData = Transformations.map(commonSettingsLiveData, settings ->
                settings == null
                        || settings.getUnit() == null
                        || UnitSystem.fromWireValue(settings.getUnit()) == UnitSystem.METRIC);
    }

    public LiveData<Boolean> getUseMMUnit() {
        return useMMUnitLiveData;
    }

    public void observeUnitDisplay(LifecycleOwner owner, Runnable onUnitChanged) {
        if (useMMUnitLiveData == null) {
            return;
        }
        useMMUnitLiveData.observe(owner, ignored -> onUnitChanged.run());
    }

    /**
     * 是否使用毫米单位
     *
     * @return
     */
    public Boolean useMMUnit() {
        if (useMMUnitLiveData == null) {
            return true;
        }
        Boolean value = useMMUnitLiveData.getValue();
        return value == null || value;
    }

    public LiveData<AdvancedSettings> getAdvancedSettingLiveData() {
        return parameterSettingsLiveData;
    }
}
