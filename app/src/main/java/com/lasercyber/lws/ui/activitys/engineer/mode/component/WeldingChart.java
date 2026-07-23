package com.lasercyber.lws.ui.activitys.engineer.mode.component;

import android.view.ViewGroup;

import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;

public interface WeldingChart {
    /**
     * 初始化图表
     */
    void initChart();

    void initData(ProcessParametersData processParametersData, Double startPower, Double endPower);

    void destroy();

    /**
     * 获取视图
     * @return
     */
    ViewGroup getView();
}
