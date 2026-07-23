package com.lasercyber.lws.ui.activitys.device.monitor;

import androidx.annotation.NonNull;
import androidx.fragment.app.Fragment;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.BaseActivity;
import com.lasercyber.lws.ui.activitys.device.monitor.fragment.AiVisionFragment;
import com.lasercyber.lws.ui.activitys.device.monitor.fragment.MachineStatusFragment;
import com.lasercyber.lws.ui.activitys.device.monitor.fragment.ProcessVideoFragment;
import com.lasercyber.lws.ui.activitys.device.monitor.fragment.WarnInfoFragment;
import com.lasercyber.lws.ui.activitys.device.monitor.fragment.WorkInfoFragment;
import com.lasercyber.lws.ui.bean.entity.TabItemBean;
import com.lasercyber.lws.ui.common.device.DeviceRemoteLockPolicy;
import com.lasercyber.lws.ui.common.device.DeviceRemoteLockStore;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.component.layout.TopTabFragmentHost;
import com.lasercyber.lws.ui.component.layout.TopTabView;
import com.lasercyber.lws.ui.databinding.ActivityDeviceMonitoringBinding;

import java.util.ArrayList;
import java.util.List;

public class DeviceMonitoringActivity extends BaseActivity<ActivityDeviceMonitoringBinding> {
    public static final String EXTRA_INITIAL_TAB_INDEX = "extra_initial_tab_index";

    private TopTabFragmentHost tabHost;

    @Override
    protected void initView() {
        statusBar();
        setupTabs();

        int initialTabIndex = getIntent().getIntExtra(EXTRA_INITIAL_TAB_INDEX, 0);
        if (initialTabIndex < 0 || initialTabIndex >= tabHost.getTabCount()) {
            initialTabIndex = 0;
        }
        tabHost.selectTab(initialTabIndex);
        binding.engineerEquipmentStatus.updateTitle(monitorTabTitle(initialTabIndex));
    }

    @Override
    protected void initData() {}

    @Override
    protected void onResume() {
        super.onResume();
        GlobalSoundManager.refreshActiveEffect(this);
        if (DeviceRemoteLockStore.isLocked()) {
            exitForRemoteLock();
        }
    }

    public void exitForRemoteLock() {
        DeviceRemoteLockPolicy.navigateToHome(this);
        finish();
    }

    @Override
    protected int getLayoutId() {
        return R.layout.activity_device_monitoring;
    }

    private void statusBar() {
        binding.engineerEquipmentStatus.setOnCallBackListener(this::finish);
    }

    private void setupTabs() {
        TopTabView topTabView = findViewById(R.id.topTabView);
        tabHost = new TopTabFragmentHost(
                this,
                topTabView,
                R.id.device_monitor_container,
                "monitor_tab_");

        List<TabItemBean> tabItems = new ArrayList<>();
        tabItems.add(new TabItemBean(R.mipmap.job_icon1, getResources().getString(R.string.work_title)));
        tabItems.add(new TabItemBean(R.mipmap.job_icon2, getResources().getString(R.string.machine_title)));
        tabItems.add(new TabItemBean(R.mipmap.job_icon3, getResources().getString(R.string.alarm_title)));
        tabItems.add(new TabItemBean(R.mipmap.videos_icon, getString(R.string.videos_text)));
        tabItems.add(new TabItemBean(R.drawable.ai_vision_home, getString(R.string.ai_vision_title)));

        List<Fragment> fragments = new ArrayList<>();
        fragments.add(new WorkInfoFragment(this));
        fragments.add(new MachineStatusFragment());
        fragments.add(new WarnInfoFragment());
        fragments.add(new ProcessVideoFragment());
        fragments.add(new AiVisionFragment());

        tabHost.setup(tabItems, fragments);
        tabHost.setOnTabShownListener((position, tabTitle) ->
                binding.engineerEquipmentStatus.updateTitle(tabTitle));
    }

    @NonNull
    private String monitorTabTitle(int index) {
        return switch (index) {
            case 1 -> getString(R.string.machine_title);
            case 2 -> getString(R.string.alarm_title);
            case 3 -> getString(R.string.videos_text);
            case 4 -> getString(R.string.ai_vision_title);
            default -> getString(R.string.work_title);
        };
    }
}
