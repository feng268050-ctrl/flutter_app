package com.lasercyber.lws.ui.bean.entity;

import lombok.Data;

@Data
public class HomeStatic {
    /*统计类型*/
    private Integer type;

    /* 统计 1*/
    private String staticTitle;
    /*数值*/
    private String staticNumber;
    /*描述*/
    private String staticInfo;

}
