package com.lasercyber.lws.ui.bean.entity.vo;


import lombok.Data;

/**
 * 焊接
 */
@Data
public class EngineerWeldingVo{
    private Integer id;
    /**
     * 焊接材料
     */
    private String weldingMaterials="";
    /**
     * 焊接厚度
     */
    private String weldingThickness="";
    /**
     * 点焊间隔（0~10000ms）
     */
    private String pointWeldingInterval="";
    /**
     * 点焊持续（0~10000ms）
     */
    private String pointWeldingDuration="";
    /**
     * 焊接功率（0~100%）
     */
    private String weldingPower="";
    /**
     * 摆动频率（0~220Hz）
     */
    private String swingFrequency="";
    /**
     * 焊接宽度（0~6mm）
     */
    private String weldingWidth="";
    /**
     * 关光延时（0~1000ms）
     */
    private String closeLightDelay="";
    /**
     * 吹气延时（0~10000ms）
     */
    private String blowDelay="";
    /**
     * 关气延时（0~10000ms）
     */
    private String closeAirDelay="";
    /**
     * 类型
     */
    private Integer type;
}