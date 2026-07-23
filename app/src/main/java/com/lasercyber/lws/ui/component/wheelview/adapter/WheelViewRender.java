package com.lasercyber.lws.ui.component.wheelview.adapter;

import android.view.View;

/**
 * 视图渲染接口
 */
public interface WheelViewRender {
    /**
     * 刷新当前视图
     * @param position
     * @param curPosition
     * @param itemView
     * @param wellSelect 即将选中
     */
    void refreshItemView(int position, int curPosition, View itemView,int wellSelect);
}
