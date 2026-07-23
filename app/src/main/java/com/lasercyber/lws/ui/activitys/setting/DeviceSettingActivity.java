package com.lasercyber.lws.ui.activitys.setting;

import android.os.Bundle;

import androidx.annotation.NonNull;
import androidx.fragment.app.Fragment;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.BaseActivity;
import com.lasercyber.lws.ui.activitys.device.monitor.fragment.DashboardFragment;
import com.lasercyber.lws.ui.activitys.setting.fragment.AdvancedSettingFragment;
import com.lasercyber.lws.ui.activitys.setting.fragment.CommonSettingsFragment;
import com.lasercyber.lws.ui.activitys.setting.fragment.DeviceInformationFragment;
import com.lasercyber.lws.ui.bean.entity.TabItemBean;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.component.layout.TopTabFragmentHost;
import com.lasercyber.lws.ui.component.layout.TopTabView;
import com.lasercyber.lws.ui.databinding.ActivityDeviceSettingBinding;

import java.util.ArrayList;
import java.util.List;

public class DeviceSettingActivity extends BaseActivity<ActivityDeviceSettingBinding> {
    public static final String EXTRA_INITIAL_TAB_INDEX = "extra_initial_tab_index";
    public static final String EXTRA_OPEN_WIRELESS_NETWORK = "extra_open_wireless_network";
    public static final int TAB_INDEX_DEVICE_INFORMATION = 0;
    public static final int TAB_INDEX_COMMON_SETTINGS = 1;
    public static final int TAB_INDEX_ADVANCED_SETTINGS = 2;
    public static final int TAB_INDEX_CUSTOM_HOME_PAGE = 3;
    public static final int TAB_INDEX_NETWORK = TAB_INDEX_COMMON_SETTINGS;
    private static final String STATE_SELECTED_TAB = "state_selected_tab";

    private TopTabFragmentHost tabHost;
    private int restoredTabIndex = -1;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        if (savedInstanceState != null) {
            restoredTabIndex = savedInstanceState.getInt(STATE_SELECTED_TAB, -1);
        }
        super.onCreate(savedInstanceState);
    }

    @Override
    protected void onSaveInstanceState(@NonNull Bundle outState) {
        super.onSaveInstanceState(outState);
        if (tabHost != null) {
            outState.putInt(STATE_SELECTED_TAB, tabHost.getCurrentTabIndex());
        }
    }

    @Override
    protected void initView() {
        statusBar();
        setupTabs();
        applyInitialTabSelection();
    }

    @Override
    protected void initData() {}

    @Override
    protected void onResume() {
        super.onResume();
        GlobalSoundManager.refreshActiveEffect(this);
    }

    @Override
    protected int getLayoutId() {
        return R.layout.activity_device_setting;
    }

    private void statusBar() {
        binding.engineerEquipmentStatus.setOnCallBackListener(this::finish);
    }

    private void setupTabs() {
        TopTabView topTabView = findViewById(R.id.setting_topTabView);
        tabHost = new TopTabFragmentHost(
                this,
                topTabView,
                R.id.device_setting_container,
                "setting_tab_");

        List<TabItemBean> tabItems = new ArrayList<>();
        tabItems.add(new TabItemBean(R.mipmap.device_info, getResources().getString(R.string.device_information)));
        tabItems.add(new TabItemBean(R.mipmap.common_settings, getResources().getString(R.string.common_settings)));
        tabItems.add(new TabItemBean(R.mipmap.settings, getResources().getString(R.string.advanced_settings)));
        tabItems.add(new TabItemBean(R.mipmap.placeholder, getResources().getString(R.string.custom_home_page)));

        List<Fragment> fragments = new ArrayList<>();
        fragments.add(new DeviceInformationFragment());
        fragments.add(new CommonSettingsFragment());
        fragments.add(new AdvancedSettingFragment());
        fragments.add(new DashboardFragment());

        tabHost.setup(tabItems, fragments);
        tabHost.setOnTabShownListener((position, tabTitle) ->
                binding.engineerEquipmentStatus.updateTitle(tabTitle));
    }

    private void applyInitialTabSelection() {
        int targetTab = getIntent().getIntExtra(EXTRA_INITIAL_TAB_INDEX, -1);
        if (targetTab < 0) {
            targetTab = restoredTabIndex >= 0 ? restoredTabIndex : 0;
        }
        if (targetTab < 0 || targetTab >= tabHost.getTabCount()) {
            targetTab = 0;
        }
        getIntent().putExtra(EXTRA_INITIAL_TAB_INDEX, targetTab);
        tabHost.selectTab(targetTab);
        binding.engineerEquipmentStatus.updateTitle(tabTitleForIndex(targetTab));
    }

    @NonNull
    private String tabTitleForIndex(int index) {
        return switch (index) {
            case TAB_INDEX_COMMON_SETTINGS -> getString(R.string.common_settings);
            case TAB_INDEX_ADVANCED_SETTINGS -> getString(R.string.advanced_settings);
            case TAB_INDEX_CUSTOM_HOME_PAGE -> getString(R.string.custom_home_page);
            default -> getString(R.string.device_information);
        };
    }
}
