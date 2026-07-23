package com.lasercyber.lws.ui.bean.entity;

import androidx.room.Entity;
import androidx.room.PrimaryKey;

import lombok.Data;

@Entity(tableName = "t_engineer_welding")
@Data
public class EngineerWelding {
    /**
     * 主键
     */
    @PrimaryKey(autoGenerate = true)
    private Integer id;
    /**
     * 焊接材料
     */
    private Integer weldingMaterials;
    /**
     * 焊接厚度
     */
    private Double weldingThickness;
    /**
     * 点焊间隔（0~10000ms）
     */
    private Integer pointWeldingInterval;
    /**
     * 点焊持续（0~10000ms）
     */
    private Integer pointWeldingDuration;
    /**
     * 焊接功率（0~100%）
     */
    private Integer weldingPower;
    /**
     * 摆动频率（0~220Hz）
     */
    private Integer swingFrequency;
    /**
     * 焊接宽度（0~6mm）
     */
    private Integer weldingWidth;
    /**
     * 关光延时（0~1000ms）
     */
    private Integer closeLightDelay;
    /**
     * 吹气延时（0~10000ms）
     */
    private Integer blowDelay;
    /**
     * 关气延时（0~10000ms）
     */
    private Integer closeAirDelay;
    /**
     * 功率缓升（0~1000ms）
     */
    private Integer powerRampUp;
    /**
     * 功率缓降（0~1000ms）
     */
    private Integer powerRampDown;
    /**
     * 送丝速度（0~50mm/s）
     */
    private Integer wireFeedSpeed;
    /**
     * 回抽长度（0~15mm）
     */
    private Integer retractLength;
    /**
     * 回抽速度 （0~300mm/s）
     */
    private Integer retractSpeed;
    /**
     * 补丝长度 （0~15mm）
     */
    private Integer fillLength;
    /**
     * 补丝时延 （0~1000ms）
     */
    private Integer fillDelay;
    /**
     * 模式类型
     *
     */
    private Integer type;
}
