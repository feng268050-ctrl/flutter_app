package com.lasercyber.lws.ui.common.utils;

import android.content.Context;
import android.widget.TextView;

import androidx.annotation.NonNull;

import com.blankj.utilcode.util.SizeUtils;
import com.lasercyber.lws.ui.R;
import com.xuexiang.xui.widget.dialog.MiniLoadingDialog;
import com.xuexiang.xui.widget.progress.loading.MiniLoadingView;

public class LoadingUtils {
    /**
     * 获取MiniLoadingDialog加载框
     *
     * @param context 上下文
     * @return MiniLoadingDialog加载框
     */
    public static MiniLoadingDialog getMiniLoadingDialog(@NonNull Context context) {
        return getMiniLoadingDialog(context, null);
    }

    /**
     * 获取MiniLoadingDialog加载框
     *
     * @param context
     * @param title   标题
     * @return
     */
    public static MiniLoadingDialog getMiniLoadingDialog(@NonNull Context context, String title) {
        MiniLoadingDialog miniLoadingDialog;
        if (title == null) {
            miniLoadingDialog = new MiniLoadingDialog(context);
        } else {
            miniLoadingDialog = new MiniLoadingDialog(context, title);
        }
        TextView textView = miniLoadingDialog.findViewById(R.id.tv_tip_message);
        MiniLoadingView miniLoadingView = miniLoadingDialog.findViewById(R.id.mini_loading_view);
        miniLoadingView.setSize(SizeUtils.dp2px(60));
        textView.setTextSize(SizeUtils.sp2px(24));
        return miniLoadingDialog;
    }
}
