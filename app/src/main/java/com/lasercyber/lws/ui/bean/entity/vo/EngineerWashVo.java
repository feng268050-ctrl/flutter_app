package com.lasercyber.lws.ui.bean.entity.vo;


import lombok.Data;

/**
 * 清洗
 */
@Data
public class EngineerWashVo {
    private Integer id;
    /**
     * 清洗材料
     */
    private String cleaningMaterials="";
    /**
     * 摆动宽度
     * 0~6mm
     */
    private String swingWidth="";

    /**
     * 激光功率（0~100%）
     */
    private String laserPower="";
    /**
     * 摆动频率（20~200Hz）
     */
    private String swingFrequency="";

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
     * 类型
     */
    private Integer type;
}
