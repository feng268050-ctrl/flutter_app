package com.lasercyber.lws.ui.activitys.setting.fragment;

import android.content.Intent;
import android.graphics.Bitmap;
import android.content.Context;
import android.util.Log;
import android.widget.ImageView;

import com.lasercyber.lws.ui.component.dialog.FrostDialog;
import androidx.fragment.app.Fragment;
import androidx.lifecycle.ViewModelProvider;

import com.lasercyber.lws.ui.BuildConfig;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.BaseFragment;
import com.lasercyber.lws.ui.activitys.setting.model.DeviceInfoViewModel;
import com.lasercyber.lws.ui.bean.entity.DeviceInfo;
import com.lasercyber.lws.ui.bean.event.DeviceUpgradeEvent;
import com.lasercyber.lws.ui.bean.event.RemoteUpdateUiEvent;
import com.blankj.utilcode.util.ToastUtils;
import com.lasercyber.lws.ui.common.config.AppRuntimeEnvironment;
import com.lasercyber.lws.ui.common.config.DeviceApiOriginProber;
import com.lasercyber.lws.ui.common.config.RetrofitClient;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.upgrade.AutoCheckOtaUpdateSettings;
import com.lasercyber.lws.ui.common.upgrade.OtaUpdateManifestService;
import com.lasercyber.lws.ui.common.upgrade.OtaUpgradeNavigation;
import com.lasercyber.lws.ui.common.utils.AdbRemoteDebugHelper;
import com.lasercyber.lws.ui.common.utils.ClickLook;
import com.lasercyber.lws.ui.common.utils.DeviceQRCodeUtils;
import com.lasercyber.lws.ui.common.utils.SecretTapTracker;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.component.dialog.GlobalDialogUtil;
import com.lasercyber.lws.ui.databinding.FragmentDeviceInformationBinding;
import com.lasercyber.lws.ui.network.http.RequestApi;

import org.greenrobot.eventbus.EventBus;
import org.greenrobot.eventbus.Subscribe;
import org.greenrobot.eventbus.ThreadMode;

import java.util.ArrayList;
import java.util.List;

/**
 * A simple {@link Fragment} subclass.
 * Use the {@link DeviceInformationFragment#newInstance} factory method to
 * create an instance of this fragment.
 * 设备信息
 */
public class DeviceInformationFragment extends BaseFragment<FragmentDeviceInformationBinding> {
    private static final String TAG = LogTAGConstant.DeviceInformationFragment;
    private  DeviceInfoViewModel deviceInfoViewModel;
    private ClickLook look = new ClickLook();
    private final SecretTapTracker deviceSnSecretTap = new SecretTapTracker();
    private final SecretTapTracker systemVersionSecretTap = new SecretTapTracker();
    private boolean suppressAutoCheckCheckboxCallback;
    @Override
    protected int getLayoutId() {
        return R.layout.fragment_device_information;
    }

    @Override
    protected void initView() {
        binding.qrCodeActive.setOnClickListener(v -> {
            openQrCode();
        });
        binding.modelValue.setOnClickListener(v -> openQrCode());
        binding.deviceSnValue.setOnClickListener(v -> {
            if (deviceSnSecretTap.registerTap()) {
                showSelectAppEnvDialog();
            }
        });
        binding.systemVersionValue.setOnClickListener(v -> {
            if (systemVersionSecretTap.registerTap()) {
                enableAdbRemoteDebugging();
            }
        });
        if(!EventBus.getDefault().isRegistered(this)){
            EventBus.getDefault().register(this);
        }
        bindAutoCheckOtaUpdate();
    }

    private void bindAutoCheckOtaUpdate() {
        if (getContext() == null) {
            return;
        }
        suppressAutoCheckCheckboxCallback = true;
        binding.autoCheckOtaUpdateCheckbox.setChecked(
                AutoCheckOtaUpdateSettings.isEnabled(requireContext()));
        suppressAutoCheckCheckboxCallback = false;
        binding.autoCheckOtaUpdateCheckbox.setOnCheckedChangeListener((checkbox, isChecked) -> {
            if (suppressAutoCheckCheckboxCallback || getContext() == null) {
                return;
            }
            if (checkbox.isPressed()) {
                GlobalSoundManager.playClickSound();
            }
            AutoCheckOtaUpdateSettings.setEnabled(requireContext(), isChecked);
        });
    }

    private void enableAdbRemoteDebugging() {
        if (getContext() == null) {
            return;
        }
        Context context = requireContext();
        ThreadPoolManager.getExecutor().execute(() -> {
            boolean ok = AdbRemoteDebugHelper.enableRemoteDebugging(context);
            handler.post(() -> {
                if (!isAdded()) {
                    return;
                }
                if (ok) {
                    ToastUtils.showLong(getString(
                            R.string.adb_remote_debug_enabled,
                            AdbRemoteDebugHelper.DEFAULT_TCP_PORT));
                } else {
                    ToastUtils.showLong(R.string.adb_remote_debug_failed);
                }
            });
        });
    }

    private void showSelectAppEnvDialog() {
        if (getContext() == null) {
            return;
        }
        List<String> labels = new ArrayList<>();
        List<AppRuntimeEnvironment.Tier> tiers = new ArrayList<>();
        if (AppRuntimeEnvironment.isDevOptionVisible()) {
            labels.add(getString(R.string.app_env_dev));
            tiers.add(AppRuntimeEnvironment.Tier.DEV);
        }
        labels.add(getString(R.string.app_env_test));
        tiers.add(AppRuntimeEnvironment.Tier.TEST);
        labels.add(getString(R.string.app_env_prod));
        tiers.add(AppRuntimeEnvironment.Tier.PROD);
        AppRuntimeEnvironment.Tier current = AppRuntimeEnvironment.getEffectiveTier();
        int checked = -1;
        for (int i = 0; i < tiers.size(); i++) {
            if (tiers.get(i) == current) {
                checked = i;
                break;
            }
        }
        GlobalDialogUtil.showSelectAppEnvDialog(
                requireContext(),
                getString(R.string.select_app_env),
                labels.toArray(new String[0]),
                checked,
                which -> {
                    AppRuntimeEnvironment.Tier chosen = tiers.get(which);
                    AppRuntimeEnvironment.persistTierOverride(requireContext(), chosen);
                    RetrofitClient.invalidate();
                    RequestApi.invalidateCachedClients();
                    DeviceApiOriginProber.onAppEnvironmentChanged(requireContext().getApplicationContext());
                    ToastUtils.showLong(R.string.app_env_changed);
                });
    }

    private void openQrCode() {
        int qrSizePx = getResources().getDimensionPixelSize(R.dimen.frost_dialog_device_qr_image_size);
        int contentPadPx = getResources().getDimensionPixelSize(R.dimen.frost_dialog_content_padding);
        int cardSizePx = qrSizePx + contentPadPx * 2;
        FrostDialog.prompt(requireContext())
                .widthPx(cardSizePx)
                .showTitle(false)
                .showActionBar(false)
                .dismissOnScrimClick(true)
                .customBodyView(R.layout.dialog_frost_body_qr_code, body -> {
                    ImageView ivQrCode = body.findViewById(R.id.device_qr_code);
                    Bitmap deviceIdentityQrCode = DeviceQRCodeUtils.createDeviceIdentityQrCodeV2(
                            qrSizePx, qrSizePx);
                    ivQrCode.setImageBitmap(deviceIdentityQrCode);
                })
                .show();
    }

    @Override
    protected void initData() {}

    @Override
    protected void bindViewModel() {
        super.bindViewModel();
        deviceInfoViewModel= new ViewModelProvider(this).get(DeviceInfoViewModel.class);
        deviceInfoViewModel.init(getContext());
        binding.setDeviceInfoViewModel(deviceInfoViewModel);
        binding.setDeviceInformationFragment(this);
        refreshCameraVersion();
    }

    @Override
    public void onResume() {
        super.onResume();
        refreshCameraVersion();
    }

    private void refreshCameraVersion() {
        if (deviceInfoViewModel == null || getContext() == null) {
            return;
        }
        deviceInfoViewModel.refreshCameraVersion(requireContext());
    }

    /**
     * 检查升级
     */
    public void checkUpgrade(){
        if (!look.clickTime(10000)) {
            GlobalDialogUtil.showStatusDialog(getContext(), 2,
                    getString(R.string.upgrade_check_rate_limit_title),
                    getString(R.string.upgrade_check_rate_limit_message));
            return;
        }

        GlobalSoundManager.playClickSound();
        GlobalDialogUtil.showStatusDialog(getContext(), 2,
                getString(R.string.upgrade_check_query_title),
                getString(R.string.upgrade_check_query_message));
        handler.postDelayed(new Runnable() {
            @Override
            public void run() {
                GlobalDialogUtil.closeDialog();
            }
        }, 10000);

        DeviceInfo value = deviceInfoViewModel.getLiveData().getValue();

        ThreadPoolManager.getExecutor().execute(() -> {
            try {
                OtaUpdateManifestService.CheckResult check = OtaUpdateManifestService.checkAgainst(BuildConfig.VERSION_NAME);
                if (!check.hasUpdate || check.manifest == null) {
                    handler.post(() -> {
                        GlobalDialogUtil.closeDialog();
                        GlobalDialogUtil.showStatusDialog(getContext(), 2,
                                getString(R.string.upgrade_already_latest_title),
                                getString(R.string.upgrade_already_latest_message));
                    });
                    return;
                }
                OtaUpdateManifestService.ManifestData manifest = check.manifest;
                handler.post(() -> {
                    GlobalDialogUtil.closeDialog();
                    OtaUpgradeNavigation.startUpgradeActivity(
                            requireContext(), manifest, value);
                });
            } catch (Exception e) {
                Log.e(TAG, "checkUpgrade manifest fetch failed", e);
                handler.post(() -> {
                    GlobalDialogUtil.closeDialog();
                    GlobalDialogUtil.showStatusDialog(getContext(), 0,
                            getString(R.string.upgrade_check_failed_title),
                            getString(R.string.upgrade_check_failed_message));
                });
            }
        });

    }

    @Subscribe(threadMode = ThreadMode.MAIN_ORDERED, sticky = true)
    public void oneDeviceUpgradeEvent(DeviceUpgradeEvent event) {
        Log.d(TAG, "设备升级事件："+event);
    }

    @Subscribe(threadMode = ThreadMode.MAIN_ORDERED)
    public void onRemoteUpdateUiEvent(RemoteUpdateUiEvent event) {
        if (!isAdded() || !isResumed() || getContext() == null) {
            return;
        }
        switch (event.getType()) {
            case UPDATE_SYSTEM_TRIGGERED:
                // Keep the same UX as manual flow; UpgradeActivity will show the standard upgrade progress/status dialog.
                break;
            case UPDATE_SYSTEM_REJECTED:
                GlobalDialogUtil.showStatusDialog(getContext(), 0, "Upgrade Failed",
                        event.getMessage() != null ? event.getMessage() : "command rejected");
                break;
        }
    }

    @Override
    public void onDestroyView() {
        if (deviceInfoViewModel!=null){
            deviceInfoViewModel.destroy();
        }
        look = null;
        super.onDestroyView();
    }
}