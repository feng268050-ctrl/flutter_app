package com.lasercyber.lws.ui.bean.entity;

import androidx.room.Entity;
import androidx.room.Ignore;
import androidx.room.PrimaryKey;

import java.util.Date;

import lombok.Data;

/*统计类*/
@Data
@Entity(tableName = "static_data")
public class StaticData {
    /*
    * 启动的时候先进行查询，如果没有，则进行添加一条数据, id固定  = 1 。
    * 【出光总时长 = 焊接+切割+清洗】
    * */
    @PrimaryKey
    private Integer id = 1;

    /*焊接总时长 （存储秒）*/
    private Long weldingTimeLength;

    /*切割总时长 （存储秒）*/
    private Long cuttingTimeLength;

    /*清洗总时长 （存储秒）*/
    private Long washTimeLength;

    /*工作时长  (存储秒)*/
    private Long jobTimeLength;

    /*焊接耗材总计 米（开光时长 * 送丝速度 [取配置中的送丝速度，如(40mm /s )]）, 在开光时，进行实时累计。
    * 只有焊接才送丝。 所以只有焊接模式才累计耗材总数。
    * */
    private Long consumableTimeLength;

    /*将上周日期和本周日期放进静态接口中，每次获取值时，做一次当前周的时间判断，超过7天则将本周时间、日期覆盖到上周，本周清零重新计算。*/

    /*上周开始计时时间*/
    private Long topStartTime;

    /*上周一的日期 yyyy-mm-dd 的字符串格式*/
    private String topDay;

    /*当前周开始计时时间*/
    private Long currStartTime;

    /*本周一的日期 yyyy-mm-dd 的字符串格式*/
    private String currDay;

    private Integer commonUse;

    /** Dominant consumable label for remote snapshot JSON only (not persisted in Room). */
    @Ignore
    private String commonUseText;
}
