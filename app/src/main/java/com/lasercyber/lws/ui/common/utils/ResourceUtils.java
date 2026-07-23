package com.lasercyber.lws.ui.common.utils;

import android.content.Context;

public class ResourceUtils {
    /**
     * 获取字符串资源
     *
     * @param resId
     * @param context
     * @return
     */
    public static String getStringText(int resId, Context context) {
        // 避免传入空上下文，可添加非空判断
        if (context != null) {
            return context.getResources().getString(resId);
        }
        return null;
    }

    public static int dp2px(Context context, float dpValue) {
        final float scale = context.getResources().getDisplayMetrics().density;
        return (int) (dpValue * scale + 0.5f);
    }
}
