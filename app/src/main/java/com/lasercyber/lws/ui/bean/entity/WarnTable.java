package com.lasercyber.lws.ui.bean.entity;

import androidx.room.Entity;
import androidx.room.Ignore;
import androidx.room.PrimaryKey;

import lombok.Data;

/*告警列表*/
@Data
@Entity(tableName = "warn_table")
public class WarnTable {

    @PrimaryKey(autoGenerate = true)
    private Long id;

    /*年月日时间 yyyy-mm-dd*/
    private String ymdDate;

    /*小时分钟时间 hh:mm:ss*/
    private String hmDate;

    /*错误码*/
    private String code;

    /*错误内容*/
    private String content;

    /*创建时间戳*/
    private Long time;

    /*最近时间戳   每次新增前，先查询是否有相同code类型、时间间隔小于10分钟的告警，如果有，则更新最新时间，否则才新增。*/
    private Long newTime;

    /**
     * 告警级别
     */
    private Integer level;

    public WarnTable(){};
    @Ignore
    public WarnTable(String ymdDate, String hmDate,String code, String content, Long time, Long newTime){
        this.ymdDate = ymdDate;
        this.hmDate = hmDate;
        this.code = code;
        this.content = content;
        this.time = time;
        this.newTime = newTime;
    }
}
