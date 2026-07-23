package com.lasercyber.lws.ui;


import android.app.Dialog;
import android.content.IntentFilter;
import android.content.Intent;
import android.graphics.drawable.Drawable;
import android.net.ConnectivityManager;
import android.graphics.Bitmap;
import android.util.Log;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.annotation.Nullable;
import androidx.core.content.ContextCompat;
import androidx.fragment.app.FragmentManager;
import androidx.fragment.app.FragmentTransaction;
import androidx.lifecycle.LiveData;
import androidx.lifecycle.ViewModelProvider;

import com.blankj.utilcode.util.LanguageUtils;
import com.blankj.utilcode.util.StringUtils;
import com.lasercyber.lws.frostui.card.interop.FrostCardView;
import com.lasercyber.lws.ui.activitys.BaseActivity;
import com.lasercyber.lws.ui.activitys.device.monitor.DeviceMonitoringActivity;
import com.lasercyber.lws.ui.activitys.device.monitor.fragment.StatisticFragment;
import com.lasercyber.lws.ui.activitys.engineer.mode.EngineerModeActivity;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.EngineerModeEntryTipsDialog;
import com.lasercyber.lws.ui.activitys.engineer.mode.model.CommonUseConsumableViewModel;
import com.lasercyber.lws.ui.activitys.engineer.mode.model.CustomLayoutViewModel;
import com.lasercyber.lws.ui.activitys.engineer.mode.model.StaticDataViewModel;
import com.lasercyber.lws.ui.activitys.quick.mode.QuickModeActivity;
import com.lasercyber.lws.ui.activitys.setting.DeviceSettingActivity;
import com.lasercyber.lws.ui.bean.entity.CommonUseConsumable;
import com.lasercyber.lws.ui.bean.entity.CustomLayout;
import com.lasercyber.lws.ui.bean.entity.Home;
import com.lasercyber.lws.ui.bean.entity.HomeStatic;
import com.lasercyber.lws.ui.bean.entity.StaticData;
import com.lasercyber.lws.ui.bean.entity.vo.WarnDialogVo;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.enums.UnitSystem;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.constant.TimeGlobalManager;
import com.lasercyber.lws.ui.common.config.AppRuntimeEnvironment;
import com.lasercyber.lws.ui.common.device.DeviceRemoteLockPolicy;
import com.lasercyber.lws.ui.common.device.DeviceRemoteLockStore;
import com.lasercyber.lws.ui.common.home.HomePromptQueue;
import com.lasercyber.lws.ui.common.camera.CameraCommunicationMonitor;
import com.lasercyber.lws.ui.common.camera.CameraRecordStateStore;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.upgrade.BundledFirmwareBootstrap;
import com.lasercyber.lws.ui.common.upgrade.SyncFirmwareTrigger;
import com.lasercyber.lws.ui.common.utils.ClickLook;
import com.lasercyber.lws.ui.common.utils.FragmentClearUtils;
import com.lasercyber.lws.ui.common.utils.WarnUtil;
import com.lasercyber.lws.ui.common.utils.WifiStatusUtils;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.component.holder.SimpleWifiConnectReceiver;
import com.lasercyber.lws.ui.component.home.HomeBackdropWebPView;
import com.lasercyber.lws.ui.component.dialog.GlobalDialogUtil;
import com.lasercyber.lws.ui.component.dialog.WarnDialogUtil;
import com.lasercyber.lws.ui.databinding.ActivityMainBinding;
import com.lasercyber.lws.ui.page.HomePage;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;

import cn.hutool.core.convert.Convert;
import cn.hutool.core.util.ObjectUtil;

public class MainActivity extends BaseActivity<ActivityMainBinding>
        implements SimpleWifiConnectReceiver.OnWifiConnectChangeListener,
        DeviceRemoteLockStore.Listener,
        CameraRecordStateStore.Listener {

    private static final String TAG = LogTAGConstant.MainActivity;
    private StaticDataViewModel staticDataViewModel;
    private CommonUseConsumableViewModel commonUseConsumableViewModel;
    private CustomLayoutViewModel customLayoutViewModel;
    private List<CustomLayout> listCustomLayout; //布局列表
    private CommonUseConsumable commonUseConsumable;//常用材料
    private StaticData staticData;//统计数据
    private String displayUnitWireValue = UnitSystem.METRIC.getWireValue();
    private Map<Integer, StatisticFragment> fragmentMap = new LinkedHashMap<>();
    private ClickLook look = new ClickLook();

    private int[] containerIds = {R.id.static_1, R.id.static_2, R.id.static_3, R.id.static_4};
    private int homeBackdropGifPending = 2;
    private SimpleWifiConnectReceiver wifiConnectReceiver;
    @Nullable
    private String lastHomeClockMinuteText;
    private final TimeGlobalManager.TimeUpdateListener homeTimeUpdateListener = currentTime -> {
        if (binding == null) {
            return;
        }
        String timeStr = new SimpleDateFormat("HH:mm", Locale.getDefault())
                .format(new Date(currentTime));
        if (timeStr.equals(lastHomeClockMinuteText)) {
            return;
        }
        lastHomeClockMinuteText = timeStr;
        binding.homeRealTime.updateTime(currentTime);
    };
    private boolean bindDeviceReminderShownInSession;

    private void refreshHomeRecordingIndicator() {
        if (binding == null || binding.homeRecordingIndicator == null) {
            return;
        }
        binding.homeRecordingIndicator.setVisibility(
                CameraRecordStateStore.isRecording() ? View.VISIBLE : View.GONE);
    }

    @Override
    public void initView() {
        textIcon();
        refreshHomeRecordingIndicator();
    }

    /*1、先查询布局内容，
     2、再查询布局数据。
     3、做fragment的渲染
     * */
    @Override
    public void initData() {
        AppDatabase.getInstance(this).commonSettingsDao().selectOneLiveData()
                .observe(this, settings -> {
                    String unit = settings != null && settings.getUnit() != null
                            ? settings.getUnit()
                            : UnitSystem.METRIC.getWireValue();
                    if (Objects.equals(displayUnitWireValue, unit)) {
                        return;
                    }
                    displayUnitWireValue = unit;
                    structureViewData();
                });
        //1、编辑一个布局库，获取前4的查询类型
        customLayoutViewModel = new ViewModelProvider(this).get(CustomLayoutViewModel.class);
        customLayoutViewModel.init(this);

        LiveData<List<CustomLayout>> customLiveData = customLayoutViewModel.customLiveData;
        customLiveData.observe(this, item -> {
            this.listCustomLayout = item;
            this.structureViewData();
        });

        //1、初始化常用耗材
        commonUseConsumableViewModel = new ViewModelProvider(this).get(CommonUseConsumableViewModel.class);
        commonUseConsumableViewModel.init(this);

        //2、初始化首页统计数据
        staticDataViewModel = new ViewModelProvider(this).get(StaticDataViewModel.class);
        staticDataViewModel.init(this);

        LiveData<StaticData> liveData = staticDataViewModel.staticLiveData;

        liveData.observe(this, item -> {
            commonUseConsumable = commonUseConsumableViewModel.getData();
            this.staticData = item;
            this.structureViewData();
        });
        commonUseConsumableViewModel.getLiveData().observe(this, dbData -> {
            commonUseConsumable = dbData;
            structureViewData();
        });
        //加载动图：原生加载，WebP 层在 BlurTarget 外避免 blur 采样 stop Animatable
        homeBackdropGifPending = 2;
        loadHomeBackdropWebP(binding.homeLeftGit, R.mipmap.home_left_400);
        loadHomeBackdropWebP(binding.homeRightGit, R.mipmap.home_right_400);

        /*绑定时间组件*/
        this.bindTime();
        bindWifiStatusIndicator();
        DeviceRemoteLockStore.addListener(this);
        CameraRecordStateStore.addListener(this);
        refreshHomeRemoteLockIcon();
        refreshHomeRecordingIndicator();
    }

    @Override
    public void onRecordingChanged(boolean recording) {
        runOnUiThread(this::refreshHomeRecordingIndicator);
    }

    private void bindWifiStatusIndicator() {
        updateHomeWifiIcon(WifiStatusUtils.isWifiConnected(getApplicationContext()), 4);
        if (wifiConnectReceiver == null) {
            wifiConnectReceiver = new SimpleWifiConnectReceiver(this);
        }
        IntentFilter filter = new IntentFilter(ConnectivityManager.CONNECTIVITY_ACTION);
        registerReceiver(wifiConnectReceiver, filter);
    }

    @Override
    protected void onPause() {
        super.onPause();
        HomePromptQueue.get().onHomePause();
        DeviceRemoteLockPolicy.resetResumeDialogCycle();
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        SyncFirmwareTrigger.deliverFromActivityIntent(this, intent);
    }

    @Override
    protected void onResume() {
        super.onResume();
        SyncFirmwareTrigger.deliverFromActivityIntent(this, getIntent());
        HomePromptQueue.get().onHomeResume(this);
        refreshHomeRemoteLockIcon();
        resumeHomeBackdropAnimations();
        if (binding != null) {
            binding.getRoot().post(this::resumeHomeBackdropAnimations);
        }
    }

    @Override
    public void onRemoteLockChanged(boolean locked) {
        refreshHomeRemoteLockIcon();
        if (locked) {
            DeviceRemoteLockPolicy.maybeShowLockDialogOnResume(this);
        } else {
            GlobalDialogUtil.dismissRemoteLockDialog();
        }
    }

    private void refreshHomeRemoteLockIcon() {
        if (binding == null || binding.homeRemoteLockIcon == null) {
            return;
        }
        binding.homeRemoteLockIcon.setVisibility(
                DeviceRemoteLockStore.isLocked() ? View.VISIBLE : View.GONE);
    }

    private void dismissWifiInitializationDialog() {
        GlobalDialogUtil.dismissCurrentDialog();
    }

    private void updateHomeWifiIcon(boolean isConnected, int level) {
        if (binding == null) {
            return;
        }
        if (!isConnected) {
            binding.homeWifiStatusIcon.setImageResource(R.mipmap.wifi_off);
            return;
        }
        int iconRes;
        switch (level) {
            case 1:
                iconRes = R.mipmap.wifi_icon_2;
                break;
            case 2:
                iconRes = R.mipmap.wifi_icon_1;
                break;
            default:
                iconRes = R.mipmap.wifi_icon;
                break;
        }
        binding.homeWifiStatusIcon.setImageResource(iconRes);
    }

    private void bindTime() {
        // 按钮1：WiFi自动校时
        TimeGlobalManager.getInstance().syncTimeWithWifi(this);

        TimeGlobalManager.getInstance().addTimeUpdateListener(homeTimeUpdateListener);

    }

    /*判断中英文,增加文字图标*/
    private void textIcon() {
        Locale locale = LanguageUtils.getAppContextLanguage();
        String language = locale.getLanguage();
        Drawable page1;
        Drawable page2;
        if (StringUtils.equals(language, "en")) {
            page1 = ContextCompat.getDrawable(this, R.mipmap.home_fast_text_en);
            page2 = ContextCompat.getDrawable(this, R.mipmap.home_engine_text_en);
        } else {
            page1 = ContextCompat.getDrawable(this, R.mipmap.home_fast_text_ch);
            page2 = ContextCompat.getDrawable(this, R.mipmap.home_engine_text_ch);
        }
        binding.toPage11.setImageDrawable(page1);
        binding.toPage21.setImageDrawable(page2);
    }

    private void loadHomeBackdropWebP(HomeBackdropWebPView imageView, int resourceId) {
        Drawable drawable = ContextCompat.getDrawable(this, resourceId);
        imageView.setImageDrawable(drawable);
        onHomeBackdropGifReady();
    }

    private void onHomeBackdropGifReady() {
        if (--homeBackdropGifPending > 0) {
            return;
        }
        refreshHomeStatCardBackdrop(true);
    }

    public void refreshHomeStatCardBackdrop() {
        refreshHomeStatCardBackdrop(false);
    }

    private void refreshHomeStatCardBackdrop(boolean force) {
        if (binding == null) {
            return;
        }
        refreshFrostCardBackdropRecursive(binding.getRoot(), force);
    }

    private void refreshFrostCardBackdropRecursive(@Nullable View view, boolean force) {
        if (view instanceof FrostCardView frostCard) {
            frostCard.refreshBackdropBlur(force);
        } else if (view instanceof ViewGroup group) {
            for (int i = 0; i < group.getChildCount(); i++) {
                refreshFrostCardBackdropRecursive(group.getChildAt(i), force);
            }
        }
    }

    public void freezePageBackdropsDuringOverlay() {
        freezePageBackdropsRecursive(binding.getRoot());
    }

    public void unfreezePageBackdropsAfterOverlay() {
        unfreezePageBackdropsRecursive(binding.getRoot());
    }

    private void resumeHomeBackdropAnimations() {
        if (binding == null) {
            return;
        }
        binding.homeLeftGit.restartAnimation();
        binding.homeRightGit.restartAnimation();
    }

    private void freezePageBackdropsRecursive(@Nullable View view) {
        if (view instanceof FrostCardView frostCard) {
            frostCard.freezePageBackdropDuringOverlay();
        } else if (view instanceof ViewGroup group) {
            for (int i = 0; i < group.getChildCount(); i++) {
                freezePageBackdropsRecursive(group.getChildAt(i));
            }
        }
    }

    private void unfreezePageBackdropsRecursive(@Nullable View view) {
        if (view instanceof FrostCardView frostCard) {
            frostCard.unfreezePageBackdropAfterOverlay();
        } else if (view instanceof ViewGroup group) {
            for (int i = 0; i < group.getChildCount(); i++) {
                unfreezePageBackdropsRecursive(group.getChildAt(i));
            }
        }
    }

    private void instertImg(ImageView ivWebP, int id) {
        Drawable drawable = ContextCompat.getDrawable(this, id);
        ivWebP.setImageDrawable(drawable);
        if (ivWebP instanceof HomeBackdropWebPView webPView) {
            webPView.restartAnimation();
        }
    }

    /* 构建视图数据。 1、布局文件更新  2、常用材料数据更新 都调用这边。*/
    private void structureViewData() {
        if (this.staticData == null || this.listCustomLayout == null || commonUseConsumable == null) {
            return;
        }
        if (staticData.getCommonUse() == null || staticData.getCommonUse() != commonUseConsumable.getCommonUse()) {
            staticDataViewModel.upCommonUse(this, commonUseConsumable.getCommonUse());
        }
        //2、封装结果对象 取排名前4的赋值
        Home home = new HomePage(this).setPageData(
                this.staticData,
                commonUseConsumable.getCommonUse(),
                this.listCustomLayout,
                displayUnitWireValue);

        /*String safety = getResources().getString(R.string.safety_operation);
        binding.safetyTitle.setText(safety);*/

        List<HomeStatic> list = home.getList();
        //先判断是否更新了list, 如果更新则清空fragmentMap
        this.addFragment(list);
    }

    /*动态添加四项统计的组件*/
    private void addFragment(List<HomeStatic> list) {
        FragmentManager fragmentManager = getSupportFragmentManager();
        // 1. 检查FragmentManager状态，避免非法状态异常
        if (fragmentManager.isStateSaved()) {// 已保存状态时不执行操作（避免崩溃）
            return;
        }
        //判断是加载还是更新
        boolean init = upFragment(fragmentManager, list);
        FragmentTransaction transaction = null;
        if ( !init ) {
            FragmentClearUtils.clearAllFragments( fragmentManager );
            transaction = fragmentManager.beginTransaction();
            fragmentMap = new LinkedHashMap<>();
        }
        int i = 0;
        /* 添加组件 */
        for ( HomeStatic homeStatic : list ) {
            if (i >= containerIds.length) {break;}

            if ( init ) {
                StatisticFragment statis = fragmentMap.get(containerIds[i]);
                statis.updateFragmentData(
                        homeStatic.getStaticNumber(),
                        homeStatic.getStaticInfo(),
                        homeStatic.getStaticTitle(),
                        homeStatic.getType());
                i++;
                continue;
            }

            StatisticFragment frag = StatisticFragment.newInstance(
                    homeStatic.getStaticNumber(),
                    homeStatic.getStaticInfo(),
                    homeStatic.getStaticTitle(),
                    homeStatic.getType());
            // 保存Fragment引用
            fragmentMap.put(containerIds[i], frag);
            // 添加到对应容器
            transaction.add(containerIds[i], frag);
            i++;
        }
        // 4. 提交事务
        if (!init) {
            transaction.commit();
        }
    }


    /*变更4大统计图标*/
    private boolean upFragment(FragmentManager fragmentManager, List<HomeStatic> list) {
        //没有的情况下，直接返回错误
        if (fragmentMap.size() == 0) {
            return false;
        }
        //否则判断map中的缓存，与当前修改的内容，内容是否一致。不一致时进行清空，并返回false.
        int i = 0;
        for (HomeStatic homeStatic : list) {
            if (i >= containerIds.length) {
                break;
            }
            StatisticFragment statis = fragmentMap.get(containerIds[i]);
            //类型不相同
            if (!ObjectUtil.equals(homeStatic.getType(), statis.getTypeKey())) {
                // 清空旧的Fragment引用和实例
                fragmentMap.clear();
                FragmentClearUtils.clearAllFragments(fragmentManager);
                return false;
                }
            i++;
        }

        //默认返回true， 只做更新
        return true;
    }

    @Override
    protected void onDestroy() {
        HomePromptQueue.get().onHostDestroyed(this);
        BundledFirmwareBootstrap.onHostDestroyed(this);
        super.onDestroy();
        Log.d(TAG, "onDestroy: 正在销毁main页面");
        DeviceRemoteLockStore.removeListener(this);
        CameraRecordStateStore.removeListener(this);
        TimeGlobalManager.getInstance().removeTimeUpdateListener(homeTimeUpdateListener);
        if (wifiConnectReceiver != null) {
            try {
                unregisterReceiver(wifiConnectReceiver);
            } catch (Exception exception) {
                Log.e(TAG, "回收首页WiFi监听异常: ", exception);
            }
            wifiConnectReceiver = null;
        }
        staticDataViewModel = null;
        commonUseConsumableViewModel = null;
        customLayoutViewModel = null;
        listCustomLayout = null; //布局列表
        commonUseConsumable = null;//常用材料
        staticData = null;//统计数据
        fragmentMap = new LinkedHashMap<>();
        look = null;

        dismissWifiInitializationDialog();
    }


    @Override
    protected int getLayoutId() {
        return R.layout.activity_main;
    }

    private void demo() {
        WarnDialogVo vo = new WarnDialogVo();
        vo.setType(WarnUtil.INFO_TYPE); // 0 = 告警 不可关闭。 1= 提示，可关闭，同时关闭激光枪的出光、出气 \ 退进丝等
        vo.setTitle(getString(R.string.security_alert_title));
        vo.setContent("It is detected that the gas pressure to the weld head is too low. Please check the gas pressure.");
        vo.setIsShowProgress(true); //[true]出现图表，如果不是图表告警则无需出现 出入[false]，否则要出现。
        vo.setProgress(113);
        vo.setUnit("kpa");
        vo.setProTitle("Gas");
        vo.setProContent("Pressure");
        vo.setMax(200);

        WarnDialogUtil.showStatusDialog(this, vo);
    }

    public void toPage(View view) {
        if (!look.clickTime()) {
            return;
        }

        GlobalSoundManager.playClickSound();
        Integer page = Convert.toInt(view.getTag());
        if (page != null && DeviceRemoteLockPolicy.blockHomeNavigationIfLocked(this, page)) {
            return;
        }
        Intent intent = null;
        //快速模式
        if (page == 1) {
            intent = new Intent(this, QuickModeActivity.class);
        }
        //工程师模式,先进入弹窗
        if (page == 2) {
            EngineerModeEntryTipsDialog.showIfNeeded(this, this::toEngineer);
        }
        //监测页面
        if (page == 3) {
            intent = new Intent(this, DeviceMonitoringActivity.class);
        }
        //设置页面
        if (page == 4) {
            intent = new Intent(this, DeviceSettingActivity.class);
        }
        // AI Vision：直接进入监测页 AI Vision Tab
        if (page == 5) {
            intent = new Intent(this, DeviceMonitoringActivity.class);
            intent.putExtra(DeviceMonitoringActivity.EXTRA_INITIAL_TAB_INDEX, 4);
        }
        /*安全页面 跳转至安全页面*/
        /*if( page == 5 ){
            open = GlobalDialogUtil.showStatusDialog(this, 2, "To Safety Tips Page ...", Utils.getApp().getString(R.string.please_wait) );
            intent = new Intent(this, SafetyTipsActivity.class);
        }*/
        if (intent == null) {
            return;
        }
        startActivity(intent);
    }

    /*跳转工程师模式*/
    private void toEngineer() {
        if (DeviceRemoteLockPolicy.blockHomeNavigationIfLocked(this, DeviceRemoteLockPolicy.HOME_PAGE_ENGINEER)) {
            return;
        }
        Intent intent = new Intent(this, EngineerModeActivity.class);
        startActivity(intent);
    }

    @Override
    public void onWifiConnectStateChanged(boolean isConnected, Integer level) {
        updateHomeWifiIcon(isConnected, level == null ? 0 : level);
        if (!AppRuntimeEnvironment.isWifiInitializationCompleted()
                && WifiStatusUtils.hasUsableWifiConnection(getApplicationContext())) {
            AppRuntimeEnvironment.markWifiInitializationCompleted(this);
            dismissWifiInitializationDialog();
            HomePromptQueue.get().onWifiOnboardingCompleted(this);
        }
    }

}



