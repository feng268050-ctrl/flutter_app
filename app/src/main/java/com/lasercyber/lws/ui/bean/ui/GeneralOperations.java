package com.lasercyber.lws.ui.bean.ui;

import java.util.HashMap;

import lombok.Data;

@Data
public class GeneralOperations {
    /**
     * 是否显示进丝
     */
    private boolean feedVisible;
    /**
     * 是否显示退丝
     */
    private boolean retractVisible;
    /**
     * 是否显示进丝使能
     */
    private boolean feedEnableVisible;
    /**
     * 是否显示退丝使能
     */
    private boolean manualGasVisible;
    /**
     * 是否显示激光使能
     */
    private boolean laserEnableVisible;
    /**
     * 类型字段
     * 1:连续焊接 2:点焊接 3:焊道清洗 4:宽幅清洗 5:手持切割
     */
    private Integer type;
    //    选中的背景样式
    private int backGroundRes;

}
