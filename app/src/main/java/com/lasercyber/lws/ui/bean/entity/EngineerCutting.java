package com.lasercyber.lws.ui.bean.entity;

import androidx.room.Entity;
import androidx.room.PrimaryKey;

import lombok.Data;

@Data
@Entity(tableName = "t_engineer_cutting")
public class EngineerCutting {
    @PrimaryKey(autoGenerate = true)
    private Integer id;
    /**
     * 切割材料
     */
    private Integer cuttingMaterials;
    /**
     * 切割厚度
     */
    private Integer cuttingThickness;

    /**
     * 激光功率（0~100%）
     */
    private Integer laserPower;
    /**
     * 激光频率（1~5000Hz）
     */
    private Integer laserFrequency;
    /**
     * 激光占空比（0~100%）
     */
    private Integer laserDutyCycle;
    /**
     * 吹气延时（0~10000ms）
     */
    private Integer blowDelay;
    /**
     * 关气延时（0~10000ms）
     */
    private Integer closeAirDelay;
    /**
     * 慢升时长 （0~1000ms）
     */
    private Integer slowRiseDuration;
    /**
     * 缓降时长 （0~1000ms）
     */
    private Integer slowDescentDuration;
    /**
     * 穿孔频率（0~2000Hz）
     */
    private Integer perforationFrequency;
    /**
     * 穿孔时长(0.1~2.0s)
     */
    private Double perforationDuration;
}
