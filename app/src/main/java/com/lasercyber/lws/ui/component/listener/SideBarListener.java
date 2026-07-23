package com.lasercyber.lws.ui.component.listener;

import com.lasercyber.lws.ui.bean.ui.SideBarItem;

/**
 * 侧边栏点击事件
 */
public interface SideBarListener {
    /**
     * 侧边栏点击事件
     * @param sidebarItem
     * @param position
     */
    void onChangSideBar(SideBarItem sidebarItem, int  position);

    /**
     * 返回首页
     */
    void callBackHome();
}
