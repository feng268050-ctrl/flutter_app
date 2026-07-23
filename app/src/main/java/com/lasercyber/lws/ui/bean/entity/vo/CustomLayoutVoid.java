package com.lasercyber.lws.ui.bean.entity.vo;

import lombok.Data;

@Data
public class CustomLayoutVoid {

    /*类型*/
    private int type;
    /*显示名称*/
    private String title;


    public CustomLayoutVoid(){

    };

    public CustomLayoutVoid(int type ,String title){
        this.type = type;
        this.title = title;
    }

}
