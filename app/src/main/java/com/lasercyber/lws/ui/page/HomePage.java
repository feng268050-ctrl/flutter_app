package com.lasercyber.lws.ui.page;

import android.content.Context;
import android.content.Intent;
import android.content.res.Resources;
import android.provider.Settings;
import android.webkit.JavascriptInterface;

import com.lasercyber.lws.ui.activitys.device.monitor.DeviceMonitoringActivity;
import com.lasercyber.lws.ui.activitys.engineer.mode.EngineerModeActivity;
import com.lasercyber.lws.ui.activitys.quick.mode.QuickModeActivity;
import com.lasercyber.lws.ui.common.device.DeviceRemoteLockPolicy;
import com.lasercyber.lws.ui.activitys.setting.DeviceSettingActivity;
import com.lasercyber.lws.ui.bean.entity.CustomLayout;
import com.lasercyber.lws.ui.bean.entity.Home;
import com.lasercyber.lws.ui.bean.entity.HomeConfig;
import com.lasercyber.lws.ui.bean.entity.StaticData;
import com.lasercyber.lws.ui.common.enums.UnitSystem;
import com.lasercyber.lws.ui.page.impl.ViewPage;

import java.util.List;

import cn.hutool.core.convert.Convert;
import cn.hutool.core.util.ObjectUtil;

public class HomePage implements ViewPage {
    private Context mContext;

    /** 实例化接口时传入上下文 */
    public HomePage(Context c) {
        mContext = c;
    }

    /*接收查询参数对象赋值
       staticData 首页默认统计数据
    * commonUse 常用耗材的枚举
    * */
    public Home setPageData(StaticData staticData, Integer commonUse, List<CustomLayout> listCustomLayout, String unitWireValue){
        //获取首页配置 如果要动态配置，则在此进行变更。
        Home home = new Home();
        home.buildHome(mContext, listCustomLayout, staticData, commonUse, resolveUnitWireValue(unitWireValue));

        return home;
    }

    public Home setPageDataToHome(StaticData staticData, String unitWireValue){

        Resources resources = mContext.getResources();

        //获取首页配置 如果要动态配置，则在此进行变更。
        HomeConfig homeConfig = new HomeConfig();

        Home home = new Home();
        home.build(resources, homeConfig, staticData, resolveUnitWireValue(unitWireValue));

        return home;
    }

    private static String resolveUnitWireValue(String unitWireValue) {
        return unitWireValue != null ? unitWireValue : UnitSystem.METRIC.getWireValue();
    }

    @JavascriptInterface
    public void openNetwork(String type){
        // 打开系统WiFi设置界面
        if(ObjectUtil.equal(type,"0")){
            Intent intent = new Intent(Settings.ACTION_WIFI_SETTINGS);
            // 可选：设置标志位，确保在新任务中启动（部分设备可能需要）
            intent.setFlags(Intent.FLAG_ACTIVITY_NO_ANIMATION);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            // 启动界面
            mContext.startActivity(intent);
        }else{
            Intent intent = new Intent(Settings.ACTION_BLUETOOTH_SETTINGS);
            // 安卓11+需添加 FLAG_ACTIVITY_NEW_TASK（可选，避免栈异常）
            intent.setFlags(Intent.FLAG_ACTIVITY_NO_ANIMATION);
            // 跳转后可通过 onActivityResult 监听用户是否开启（安卓11+需用 registerForActivityResult）
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            mContext.startActivity(intent);
        }

    }

    @JavascriptInterface
    public void toPage(String index) {
        int page = Convert.toInt(index);
        if (DeviceRemoteLockPolicy.blockHomeNavigationIfLocked(mContext, page)) {
            return;
        }
        Intent intent = null;
        //快速模式
        if(page == 1){intent = new Intent(mContext, QuickModeActivity.class);}
        //工程师模式
        if(page == 2){intent = new Intent(mContext, EngineerModeActivity.class);}
        //监测页面
        if(page == 3){intent = new Intent(mContext, DeviceMonitoringActivity.class);}
        //设置页面
        if(page == 4){intent = new Intent(mContext, DeviceSettingActivity.class);}
        // AI Vision Tab
        if(page == 5){
            intent = new Intent(mContext, DeviceMonitoringActivity.class);
            intent.putExtra(DeviceMonitoringActivity.EXTRA_INITIAL_TAB_INDEX, 4);
        }
        if(intent == null){
            return;
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        mContext.startActivity(intent);
    }
}
