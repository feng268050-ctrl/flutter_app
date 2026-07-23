package com.lasercyber.lws.ui.bean.entity.vo;

import androidx.room.PrimaryKey;

import com.lasercyber.lws.ui.bean.entity.WarnTable;

import java.util.List;

import lombok.Data;

@Data
public class WarnTableVo {

    /*告警列表*/
    List<WarnTable> listData;

    /*页码*/
    private Integer page;

    /*页大小*/
    private Integer number;
}
