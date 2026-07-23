package com.lasercyber.lws.ui.activitys.engineer.mode.listener;

import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;

/**
 * 下发工艺参数监听
 */
public interface SendProcessParametersDataListener {
    void updateProcessParamsDataAndSend();

    void sendDataProxy();

    /**
     * 发送配置
     */
    void sendData();

    /**
     * 送丝速度
     */
    Double wireFeedSpeed();

    /**
     * 参数校验
     * @return
     */
    boolean paramsCheck();
    ProcessParametersData getProcessParametersData();

    /**
     * 发送高级配置的数据
     */
    void sendAdvanceSettingData();

    /**
     * 界面激活监听
     */
    void setEngineerPageActiveListener(EngineerPageActiveListener engineerPageActiveListener);

    /**
     * 当前工艺 Tab 被选中时刷新参数表单（ViewPager 懒加载页可能在非激活时已完成数据加载）。
     */
    void onEngineerPageActivated();
}
