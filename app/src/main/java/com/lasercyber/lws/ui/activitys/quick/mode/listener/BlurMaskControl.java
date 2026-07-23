package com.lasercyber.lws.ui.activitys.quick.mode.listener;

/**
 * Fragment 与 Activity 的通信接口，用于操作全局模糊蒙版
 */
public interface BlurMaskControl {
    // 显示模糊蒙版，并设置清晰可点击的目标视图
    void showBlurMask();
    // 隐藏模糊蒙版
    void hideBlurMask();
}
