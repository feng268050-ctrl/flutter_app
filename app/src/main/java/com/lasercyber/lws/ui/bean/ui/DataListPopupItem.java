package com.lasercyber.lws.ui.bean.ui;

import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.constant.ProcessDataType;

import lombok.Data;

@Data
public class DataListPopupItem {
    private int iconRes;  // 图标资源ID
    private String name;  // 材质名称
    private boolean isSelected;  // 是否选中
    private long id;
    /**
     * 工艺类型
     * {@link ModelConstant}
     */
    private Integer processType;
    /**
     * 数据类型
     * {@link ProcessDataType}
     */
    private Integer dataType;

    public DataListPopupItem(int iconRes, String name, boolean isSelected) {
        this.iconRes = iconRes;
        this.name = name;
        this.isSelected = isSelected;
    }

}
