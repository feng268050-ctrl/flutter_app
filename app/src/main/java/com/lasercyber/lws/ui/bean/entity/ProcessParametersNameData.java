package com.lasercyber.lws.ui.bean.entity;

import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.constant.ProcessDataType;

import java.io.Serializable;

import lombok.Data;

/**
 * 工艺参数名称信息
 */
@Data
public class ProcessParametersNameData implements Serializable {
    private Long id;
    /**
     * 名称
     */
    private String name;
    /**
     * 材料类型代码
     */
    private Integer materialType;
    /**
     * 材质名称，用于自定义材质
     */
    private String materialName;

    /**
     * 工艺类型
     * {@link ModelConstant}
     */
    private Integer processType;
    /**
     * 数据类型：0 快速模式参数；1 工程师模式内置参数；2 工程师模式自定义参数；3 视频工艺参数（废弃）。
     * {@link ProcessDataType}
     */
    private Integer dataType;
}
