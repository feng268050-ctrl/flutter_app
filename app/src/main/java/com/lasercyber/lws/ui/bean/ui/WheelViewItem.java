package com.lasercyber.lws.ui.bean.ui;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.experimental.Accessors;

@Data
@Accessors(chain = true)
@AllArgsConstructor
@NoArgsConstructor
public class WheelViewItem {
    private String text;
    private int type;
    /**
     * 背景图片资源
     */
    private int backGroundRes=-1;
    /**
     * 数据的位置
     */
    private int position;
    public WheelViewItem(String text, int type, int backGroundRes){
        this.text = text;
        this.type = type;
        this.backGroundRes = backGroundRes;
    }
    public WheelViewItem(String text, int type){
        this.text = text;
        this.type = type;
    }
}
