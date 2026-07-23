package com.lasercyber.lws.ui.bean.entity;

// 封装Tab数据（Icon+标题）
public class TabItemBean {
    private int iconResId;
    private String title;

    public TabItemBean(int iconResId, String title) {
        this.iconResId = iconResId;
        this.title = title;
    }

    public int getIconResId() { return iconResId; }
    public String getTitle() { return title; }

}
