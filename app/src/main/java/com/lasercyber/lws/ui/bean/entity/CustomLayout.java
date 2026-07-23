package com.lasercyber.lws.ui.bean.entity;

import androidx.room.Entity;
import androidx.room.Ignore;
import androidx.room.PrimaryKey;

import lombok.Data;

@Data
@Entity(tableName = "custom_layout")
public class CustomLayout {

    @PrimaryKey(autoGenerate = true)
    private Integer id;
    //布局位置
    private Integer laoutIndex;

    //统计类型
    private Integer type;

    public CustomLayout(){};
    @Ignore
    public CustomLayout(int laoutIndex, int type){
        this.laoutIndex = laoutIndex;
        this.type = type;
    }
}
