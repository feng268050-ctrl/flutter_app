package com.lasercyber.lws.ui.bean.entity.vo;



import androidx.databinding.BaseObservable;
import androidx.databinding.Bindable;

import com.lasercyber.lws.ui.BR;

import lombok.Data;
import lombok.EqualsAndHashCode;

/**
 * 切割模式数据
 */
@Data
public class EngineerCuttingVo {
    private Integer id;
    /**
     * 切割材料
     */
    private String cuttingMaterials="";
    /**
     * 切割厚度
     */
    private String cuttingThickness="";

    /**
     * 激光功率（0~100%）
     */
    private String laserPower="";
    /**
     * 激光频率（1~5000Hz）
     */
    private String laserFrequency="";
    /**
     * 激光占空比（0~100%）
     */
    private String laserDutyCycle="";
    /**
     * 吹气延时（0~10000ms）
     */
    private String blowDelay="";
    /**
     * 关气延时（0~10000ms）
     */
    private String closeAirDelay="";
    /**
     * 慢升时长 （0~1000ms）
     */
    private String slowRiseDuration="";
    /**
     * 缓降时长 （0~1000ms）
     */
    private String slowDescentDuration="";
    /**
     * 穿孔频率（0~2000Hz）
     */
    private String perforationFrequency="";
    /**
     * 穿孔时长(0.1~2.0s)
     */
    private String perforationDuration;
}
