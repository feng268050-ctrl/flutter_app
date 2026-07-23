package com.lasercyber.lws.ui.common.utils.bean;

public class StatItem {

    public static final int TYPE_RING = 0;
    public static final int TYPE_DATA = 1;

    private int type;
    private String title;
    private String value;
    private int color; // 仅环形卡片使用
    private String info;

    // 数据卡片构造
    public StatItem(int type, String title, String value, String info) {
        this.type = type;
        this.title = title;
        this.value = value;
        this.info = info;
    }

    // 环形卡片构造
    public StatItem(int type, String title, String value, String info, int color) {
        this.type = type;
        this.title = title;
        this.value = value;
        this.color = color;
        this.info = info;
    }

    public int getType() { return type; }
    public String getTitle() { return title; }
    public String getValue() { return value; }
    public int getColor() { return color; }
    public String getInfo() { return info; }
}
