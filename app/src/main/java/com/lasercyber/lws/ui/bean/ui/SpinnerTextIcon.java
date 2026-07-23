package com.lasercyber.lws.ui.bean.ui;

import lombok.Data;

@Data
public class SpinnerTextIcon {
    /**
     * 文本id
     */
    private int textId;
    /**
     * 图标id
     */
    private int iconId;
    /**
     * 文本
     */
    private String text;
    public static SpinnerTextIcon create(int textId, int iconId) {
        SpinnerTextIcon item = new SpinnerTextIcon();
        item.textId = textId;
        item.iconId = iconId;
        return item;
    }
    public static SpinnerTextIcon create(String text, int iconId) {
        SpinnerTextIcon item = new SpinnerTextIcon();
        item.text = text;
        item.iconId = iconId;
        return item;
    }
}
