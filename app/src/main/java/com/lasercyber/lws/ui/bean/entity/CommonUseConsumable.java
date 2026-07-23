package com.lasercyber.lws.ui.bean.entity;

import androidx.room.Entity;
import androidx.room.PrimaryKey;

import lombok.Data;

/*常用耗材记录表*/
@Data
@Entity(tableName = "common_use_consumable")
public class CommonUseConsumable {

    /*
    * 先查询数据库，有没有相同类型，有则修改 number = number +1
    * 没有则创建一个。
    * */

    /*常用耗材 (枚举， 用下标对应) 主键*/
    @PrimaryKey
    private Integer commonUse;

    /*使用次数 ,每使用一次进行 累加+1*/
    private Long useNumber;

}
