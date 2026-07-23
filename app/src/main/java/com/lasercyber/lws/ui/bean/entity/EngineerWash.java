package com.lasercyber.lws.ui.bean.entity;

import androidx.room.Entity;
import androidx.room.PrimaryKey;

import lombok.Data;

@Data
@Entity(tableName = "t_engineer_wash")
public class EngineerWash {
    @PrimaryKey(autoGenerate = true)
    private Integer id;
    /**
     * 清洗材料
     */
    private Integer cleaningMaterials;
    /**
     * 摆动宽度
     * 0~6mm
     */
    private Integer swingWidth;

    /**
     * 激光功率（0~100%）
     */
    private Integer laserPower;
    /**
     * 摆动频率（20~200Hz）
     */
    private Integer swingFrequency;

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
     * 类型
     */
    private Integer type;
}
