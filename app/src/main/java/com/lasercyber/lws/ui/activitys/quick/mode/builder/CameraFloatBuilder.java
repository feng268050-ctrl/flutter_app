package com.lasercyber.lws.ui.activitys.quick.mode.builder;

import android.content.Context;
import android.view.View;

import com.lasercyber.lws.ui.R;
import com.lzf.easyfloat.EasyFloat;
import com.lzf.easyfloat.enums.SidePattern;

public class CameraFloatBuilder {
    /**
     * 创建基础的相机浮窗
     *
     * @param activity activity的content
     * @param view     浮窗的view
     * @return 浮窗的builder
     */
    public static EasyFloat.Builder createBaseCameraFloat(Context activity, View view) {
        return EasyFloat.with(activity)
                .setImmersionStatusBar(true)
                // 设置浮窗xml布局文件/自定义View，并可设置详细信息
                .setLayout(view)
                // 设置吸附
                .setSidePattern(SidePattern.RESULT_HORIZONTAL)
                .setLocation(0, (int) activity.getResources().getDimension(R.dimen.camera_float_default_y))
                // 设置浮窗是否可拖拽
                .setDragEnable(true);
    }
}
