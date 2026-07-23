package com.lasercyber.lws.ui.bean.ui;

import lombok.Data;
import lombok.experimental.Accessors;

/**
 * 侧边栏的每一项
 */
@Data
@Accessors(chain = true)
public class SideBarItem {
    /**
     * 使用title资源定义的id
     */
    private int titleTextId;
    public static SideBarItem create(int titleTextId){
        return new SideBarItem().setTitleTextId(titleTextId);
    }
}
