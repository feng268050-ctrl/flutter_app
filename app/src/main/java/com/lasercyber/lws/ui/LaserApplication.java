package com.lasercyber.lws.ui;

import android.app.Application;
import android.content.Context;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.NetworkRequest;
import android.os.Handler;
import android.os.Looper;
import android.os.StrictMode;
import android.util.Log;

import androidx.annotation.NonNull;

import com.blankj.utilcode.util.ToastUtils;
import com.blankj.utilcode.util.Utils;
import com.bumptech.glide.Glide;
import com.bumptech.glide.GlideBuilder;
import com.lasercyber.lws.ui.activitys.engineer.mode.model.StaticDataViewModel;
import com.lasercyber.lws.ui.activitys.engineer.mode.model.WarnTableViewModel;
import com.lasercyber.lws.ui.activitys.setting.model.AdvancedSettingViewModel;
import com.lasercyber.lws.ui.bean.entity.AdvancedSettings;
import com.lasercyber.lws.ui.bean.event.ServiceDestroyEvent;
import com.lasercyber.lws.ui.common.call.NetworkCallback;
import com.lasercyber.lws.ui.common.config.AppRuntimeEnvironment;
import com.lasercyber.lws.ui.common.config.ModbusConfig;
import com.lasercyber.lws.ui.common.device.DeviceRemoteLockStore;
import com.lasercyber.lws.ui.common.config.DeviceModelConfig;
import com.lasercyber.lws.ui.common.config.DeviceApiOriginProber;
import com.lasercyber.lws.ui.common.constant.DeviceStatusConstant;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.constant.LwsCloudSyncLog;
import com.lasercyber.lws.ui.common.constant.StaticConstant;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.enums.TimingJobType;
import com.lasercyber.lws.ui.common.gpio.LedIndicatorManager;
import com.lasercyber.lws.ui.common.camera.CameraCommunicationMonitor;
import com.lasercyber.lws.ui.common.camera.CameraRecordSaveHandler;
import com.lasercyber.lws.ui.common.handler.DeviceStatusTaskHandler;
import com.lasercyber.lws.ui.common.handler.LensHeavyContaminationWarnAlarm;
import com.lasercyber.lws.ui.common.handler.ZeroPointOffsetWarnAlarm;
import com.lasercyber.lws.ui.common.mdns.DeviceMdnsAdvertiseManager;
import com.lasercyber.lws.ui.common.mdns.DeviceMdnsWifiNetworkCallback;
import com.lasercyber.lws.ui.common.network.CameraEth0LinkMonitor;
import com.lasercyber.lws.ui.common.network.CameraEth0WifiNetworkCallback;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusManagerRtu;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusStartupCapabilityDecider;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusStartupState;
import com.lasercyber.lws.ui.common.rx.modbus.call.InitModbusCallBack;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusFiledBuilder;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusHexData;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.TimingJobContent;
import com.lasercyber.lws.ui.common.rx.modbus.task.TimingJobTask;
import com.lasercyber.lws.ui.common.rx.modbus.task.TimingJobTaskManager;
import com.lasercyber.lws.ui.common.boot.BootSelfCheckSettings;
import com.lasercyber.lws.ui.component.dialog.FrostUiDialogBridge;
import com.lasercyber.lws.ui.common.settings.AiAssistanceSettings;
import com.lasercyber.lws.ui.common.settings.DangerousOperationsSettings;
import com.lasercyber.lws.ui.common.settings.SoundEffectSettings;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.utils.DefaultValueUtils;
import com.lasercyber.lws.ui.common.utils.SystemSettingUtils;
import com.lasercyber.lws.ui.common.utils.VideoFileUtil;
import com.lasercyber.lws.ui.common.utils.json.GsonInitUtils;
import com.lasercyber.lws.ui.common.upgrade.BundledLibraryBootstrap;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.network.http.local.CameraLanHttpProxy;
import com.lasercyber.lws.ui.network.http.local.DeviceLocalHttpServer;
import com.lasercyber.lws.ui.network.mediamtx.MediaMtxRelayCoordinator;
import com.lasercyber.lws.ui.network.ws.DeviceWebSocketConnectionManager;
import com.lasercyber.lws.ai.daemon.AiDaemonSupervisor;
import com.lasercyber.lws.ai.engine.AiManager;
import com.lasercyber.lws.ai.sampling.LiveInferGraceCoordinator;
import com.lasercyber.lws.ai.stain.OpencvStainDetectCoordinator;
import com.lasercyber.lws.ai.zeropoint.ZeroPointDetectCoordinator;

import org.greenrobot.eventbus.EventBus;
import org.greenrobot.eventbus.Subscribe;
import org.greenrobot.eventbus.ThreadMode;

import java.util.List;
import java.util.Objects;
import java.io.File;

public class LaserApplication extends Application {
    private static final String TAG = LogTAGConstant.APPLICATION;

    @Override
    public void onCreate() {
        super.onCreate();
        if (Objects.equals(BuildConfig.DEBUG, Boolean.TRUE)) {
            StrictMode.setThreadPolicy(new StrictMode.ThreadPolicy.Builder()
                    .detectDiskReads() // 检测主线程磁盘读
                    .detectDiskWrites() // 检测主线程磁盘写
                    .detectNetwork() // 检测主线程网络请求
                    .penaltyLog() // 违规操作打印日志
                    .detectAll()
                    .build());
        }
        Log.d(LogTAGConstant.APPLICATION, "正在启动 LaserApplication=====>");
        AppRuntimeEnvironment.init(this);
        VideoFileUtil.ensureRuntimePath(this);
        FrostUiDialogBridge.register();
        DeviceRemoteLockStore.init(this);
        DeviceModelConfig.preload();
        this.initEffect();
        this.initBaseCommon();
        // 系统参数设置
        ThreadPoolManager.getExecutor().execute(this::systemParamsSetting);
        // 初始化硬件
        this.initBaseHardware();
        // 监听网络
        this.initNetworkCallback();
        // 设备侧 mDNS 广播（JmDNS；须在 initMdnsWifiNetworkCallback 前 start，以便收到 Wi-Fi Network 后发布）
        DeviceMdnsAdvertiseManager.getInstance().start(this);
        DeviceLocalHttpServer.getInstance().start(this);
        CameraLanHttpProxy.getInstance().start(this);
        CameraRecordSaveHandler.ensureRegistered();
        MediaMtxRelayCoordinator.getInstance().init(this);
        ThreadPoolManager.getExecutor().execute(
                () -> MediaMtxRelayCoordinator.getInstance().startForLanPreview());
        this.initMdnsWifiNetworkCallback();
        this.initCameraEth0WifiNetworkCallback();
        this.initCameraEth0LinkMonitor();
        //初始化调用业务
        this.initSysService();

    }

    /*初始化调用业务*/
    private void initSysService() {
        //1、清除告警
        this.initWarn();
        //2、开启定时任务
        this.InitAddJobTime();
    }

    /*清空3个月之前的告警*/
    private void initWarn() {
        WarnTableViewModel warnTableViewModel = new WarnTableViewModel();
        warnTableViewModel.deleteTimeHalfYear(getBaseContext());
    }

    /**
     * 启动后台录制视频
     */
    private void startLoopRecordService() {
        // Background loop recording intentionally disabled.
    }

    /**
     * 初始化硬件
     */
    private void initBaseHardware() {
        ThreadPoolManager.getExecutor().execute(() -> {
            // 开启绿色的灯（模拟器/无YNHAPI时允许降级跳过）
            try {
                LedIndicatorManager.syncHardwareToCachedModes();
            } catch (Throwable throwable) {
                logStartupPhase("gpio_init", "failed", "YNHAPI_UNAVAILABLE", throwable);
            }
            // 启动后台录制视频
            startLoopRecordService();
            // 打开串口
            initSerialPort();
            initAiDaemon();
            initAiEngine();
        });
    }

    /**
     * 初始化基础组件
     */
    private void initBaseCommon() {
        LaserApplication application = this;
        ThreadPoolManager.getExecutor().execute(() -> {
            // 注册 EventBus
            EventBus.getDefault().register(application);
            LensHeavyContaminationWarnAlarm.INSTANCE.start(application);
            Log.d(LogTAGConstant.APPLICATION, "事件总线注册完成...");
            // 初始化 AndroidUtilCode
            Utils.init(application);  // 传入Application实例，必须调用
            // 初始化自定义的gson
            GsonInitUtils.initGson();
            // 冷启动：跑 API pin 探测；探测成功后由 DeviceApiOriginProber 入队待传封面（WorkManager + 线程池试传）。
            schedulePendingVideoMetadataAfterColdStart(application);
            // 初始化Toast的字体大小
            ToastUtils.getDefaultMaker().setTextSize(24);
            Log.d(LogTAGConstant.APPLICATION, "AndroidUtilCode 初始化完成...");
            // 提前初始化图片加载框架
            Glide.init(application, new GlideBuilder());
            BundledLibraryBootstrap.run(application);
            BootSelfCheckSettings.warmCache(application);
            AiAssistanceSettings.warmCache(application);
            DangerousOperationsSettings.warmCache(application);
            SoundEffectSettings.warmCache(application);
        });

    }

    /**
     * After reboot: kick API-origin probing on the active default network when present.
     * Process-video cover upload is not auto-drained over HTTP metadata; this path only probes API origin and WS.
     */
    private static void schedulePendingVideoMetadataAfterColdStart(Context app) {
        LwsCloudSyncLog.i("App", "cold start: schedule API origin probe only (metadata enqueue after pin)");
        try {
            ConnectivityManager cm = (ConnectivityManager) app.getSystemService(Context.CONNECTIVITY_SERVICE);
            Network active = cm != null ? cm.getActiveNetwork() : null;
            if (active == null) {
                Log.i(TAG, "cold start: no active network, skip immediate API origin probe");
                LwsCloudSyncLog.i("App", "no active network at cold start (getActiveNetwork null) — wait for NetworkCallback");
                return;
            }
            LwsCloudSyncLog.i("App", "cold start: schedule probe on active network");
            DeviceApiOriginProber.probeWhenNetworkAvailable(active, () -> {
                try {
                    DeviceWebSocketConnectionManager.getInstance().connectOrReconnect("cold_start_active_network");
                } catch (Throwable inner) {
                    Log.e(TAG, "cold start: ws bootstrap skipped", inner);
                    LwsCloudSyncLog.e("App", "ws bootstrap skipped", inner);
                }
            });
        } catch (Throwable t) {
            Log.w(TAG, "cold start: API origin probe scheduling failed", t);
            LwsCloudSyncLog.w("App", "probe scheduling failed", t);
        }
    }

    /*初始化操作音频*/
    private void initEffect() {
        int effect = SoundEffectSettings.getIndexBlocking(this);
        GlobalSoundManager.ensureInitialized(this, effect);
    }

    /*初始化累积工作时长*/
    public void InitAddJobTime() {
        ThreadPoolManager.getExecutor().execute(() -> {
            StaticDataViewModel model = new StaticDataViewModel();

            //调用定时任务
            TimingJobTask timingJobTask = new TimingJobTask();
            timingJobTask.setTaskId(TimingJobType.JOB_TIME_LENGTH.name());

            timingJobTask.startRun(new TimingJobContent() {
                @Override
                public void run() {
                    Context applicationContext = getApplicationContext();
                    //1、清空上一次开机的工作时长，可根据定时任务的状态变动而调整。
                    if (!timingJobTask.isCancelled() && !timingJobTask.isUpCancelled()) {
                        model.clearJobTimeLength(applicationContext);
                        //下次则不再清空
                        timingJobTask.setUpCancelled(true);
                    } else {
                        //2、调用增加1分钟的开机时长。
                        model.weldStop(StaticConstant.jobTime, 60, 0L, applicationContext, null);
                    }
                }
            });
            TimingJobTaskManager.getInstance().addTask(timingJobTask);
        });
    }

    /**
     * 初始化串口
     */
    public void initSerialPort() {
        ThreadPoolManager.getExecutor().execute(() -> {
            try {
                logStartupPhase("modbus_init", "start", "begin", null);
                final boolean skipModbus = shouldSkipModbusForCurrentRuntime();
                if (skipModbus) {
                    logStartupPhase("modbus_init", "skipped", ModbusStartupState.getReasonCode(), null);
                    notifyModbusUnavailableOnMainThread(ModbusStartupState.getReasonCode());
                    if (ModbusConfig.isMock()) {
                        DeviceStatusTaskHandler.recreateDeviceStatusTask(
                                DeviceStatusConstant.POLL_TIMER_INTERVAL_MS);
                        logStartupPhase("modbus_init", "mock_poll_started", "emulator", null);
                    }
                } else {
                    AdvancedSettings parameterSettings =
                            AppDatabase.getInstance(getApplicationContext()).advancedSettingsDao().selectOne();
                    if (parameterSettings == null) {
                        AdvancedSettings defaultSetting = DefaultValueUtils.createDefaultAdvancedSettings();
                        long parameterId = AppDatabase.getInstance(getApplicationContext())
                                .advancedSettingsDao().insert(defaultSetting);
                        Log.d(TAG, "保存的参数配置Id:" + parameterId);
                        parameterSettings = defaultSetting;
                    }
                    AdvancedSettings settingsToPush = parameterSettings;
                    InitModbusCallBack initModbusCallBack = new InitModbusCallBack(() -> {
                        DeviceStatusTaskHandler.recreateDeviceStatusTask(
                                DeviceStatusConstant.POLL_TIMER_INTERVAL_MS);
                        List<ModbusHexData> writeDeviceSetting =
                                ModbusFiledBuilder.doCreateWriteDeviceSetting(settingsToPush);
                        ModbusManagerRtu.get().writeRegisters(writeDeviceSetting);
                    });
                    ModbusManagerRtu.get().openSerialPort(initModbusCallBack);
                    logStartupPhase("modbus_init", "open_requested", "async_init_requested", null);
                }

                LiveInferGraceCoordinator.getInstance().attach(getApplicationContext());
                ZeroPointDetectCoordinator.getInstance().attach(getApplicationContext());

                logStartupPhase("modbus_init", "done", "startup_continue", null);
            } catch (Throwable throwable) {
                ModbusStartupState.markUnavailable(ModbusStartupState.REASON_UNEXPECTED_ERROR, "initSerialPort fatal throwable", throwable);
                logStartupPhase("modbus_init", "failed", ModbusStartupState.REASON_UNEXPECTED_ERROR, throwable);
                notifyModbusUnavailableOnMainThread(ModbusStartupState.REASON_UNEXPECTED_ERROR);
            }
        });
    }

    private boolean shouldSkipModbusForCurrentRuntime() {
        File serialDevice = new File(com.lasercyber.lws.ui.common.config.SerialPortConfig.DEVICE_PATH);
        ModbusStartupCapabilityDecider.Decision decision = ModbusStartupCapabilityDecider.decide(
                android.os.Build.FINGERPRINT,
                android.os.Build.MODEL,
                serialDevice.exists()
        );
        if (decision.shouldSkip()) {
            ModbusStartupState.markUnavailable(
                    decision.reasonCode(),
                    "Serial device missing: " + serialDevice.getAbsolutePath(),
                    null
            );
            return true;
        }
        return false;
    }

    private void logStartupPhase(String phase, String outcome, String reason, Throwable throwable) {
        String msg = "startup_phase=" + phase + ", outcome=" + outcome + ", reason=" + reason;
        if (throwable == null) {
            Log.i(LogTAGConstant.APPLICATION, msg);
        } else {
            Log.e(LogTAGConstant.APPLICATION, msg, throwable);
        }
    }

    private void notifyModbusUnavailableOnMainThread(String reasonCode) {
        new Handler(Looper.getMainLooper()).post(() ->
                Log.w(LogTAGConstant.APPLICATION, "Modbus unavailable (" + reasonCode + "), running in degraded mode")
        );
    }

    // 监听服务销毁事件，自动重启
    @Subscribe(threadMode = ThreadMode.MAIN)
    public void onServiceDestroy(ServiceDestroyEvent event) {
        Log.d(TAG, "onServiceDestroy: 尝试重启");
    }

    @Override
    public void onTerminate() {
        super.onTerminate();
        DeviceMdnsAdvertiseManager.getInstance().stop();
        DeviceLocalHttpServer.getInstance().shutdown();
        CameraLanHttpProxy.getInstance().shutdown();
        CameraCommunicationMonitor.stop();
        LensHeavyContaminationWarnAlarm.INSTANCE.stop();
        ZeroPointOffsetWarnAlarm.INSTANCE.resetForStop();
        ZeroPointDetectCoordinator.getInstance().detach();
        OpencvStainDetectCoordinator.getInstance().detach();
        LiveInferGraceCoordinator.getInstance().detach();
        AiDaemonSupervisor.getInstance().stop();
        AiManager.getInstance().stop();
        EventBus.getDefault().unregister(this);
    }

    /**
     * 初始化镜片检测（资产部署 + daemon IPC；失败仅记日志，不阻塞其它启动流程）。
     */
    private void initAiEngine() {
        try {
            boolean started = AiManager.getInstance().start(this);
            ZeroPointDetectCoordinator.getInstance().ensureNativeDetectorReady();
            AiManager manager = AiManager.getInstance();
            boolean daemonReady = AiDaemonSupervisor.getInstance().isReady();
            if (manager.isOpencvStainDetectSessionActive() || daemonReady) {
                logStartupPhase("lens_guard", "ok", "stain_detect_ready", null);
                OpencvStainDetectCoordinator.getInstance().attach(this);
            } else if (started) {
                logStartupPhase("lens_guard", "ok", "assets_ready_awaiting_daemon", null);
            } else {
                logStartupPhase("lens_guard", "failed", "engine_start_returned_false", null);
            }
        } catch (Throwable throwable) {
            logStartupPhase("lens_guard", "failed", "unexpected_throwable", throwable);
        }
    }

    /**
     * Start independent AI C++ daemon. Failure is non-fatal for other subsystems.
     */
    private void initAiDaemon() {
        try {
            boolean ok = AiDaemonSupervisor.getInstance().start(this);
            if (!ok) {
                logStartupPhase("ai_daemon", "failed", "supervisor_start_returned_false", null);
            }
            // markDaemonReady applies once AiManager.start has deployed assets (called from Supervisor
            // on RUNNING, and again here after start in case assets were already deployed).
            AiManager.getInstance().markDaemonReady();
        } catch (Throwable throwable) {
            logStartupPhase("ai_daemon", "failed", "unexpected_throwable", throwable);
        }
    }

    /**
     * Android 7.0+ 用 NetworkCallback 监听网络
     */
    private void initNetworkCallback() {
        ConnectivityManager cm = (ConnectivityManager) getSystemService(CONNECTIVITY_SERVICE);
        if (cm == null) return;
        // 构建网络请求：仅监听 WiFi 和 蜂窝网络（4G属于蜂窝网络）
        NetworkRequest networkRequest = new NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) // 仅监听有互联网的网络
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)     // 仅监听 WiFi
                .addTransportType(NetworkCapabilities.TRANSPORT_CELLULAR) // 仅监听蜂窝网络（4G/5G）
                .build();

        // 注册网络回调（全局生效，与Application生命周期一致）
        cm.registerNetworkCallback(networkRequest, new NetworkCallback());
    }

    /**
     * mDNS 必须在「仅局域网、未通过互联网检测」的 Wi-Fi 上也能发布；不能用带 NET_CAPABILITY_INTERNET 的 NetworkRequest。
     */
    private void initMdnsWifiNetworkCallback() {
        ConnectivityManager cm = (ConnectivityManager) getSystemService(CONNECTIVITY_SERVICE);
        if (cm == null) {
            return;
        }
        NetworkRequest wifiLan = new NetworkRequest.Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                .build();
        cm.registerNetworkCallback(wifiLan, new DeviceMdnsWifiNetworkCallback());
    }

    /** Re-apply {@code eth0} when Wi-Fi DHCP address changes (avoid {@code wlan0} / {@code eth0} clash). */
    private void initCameraEth0WifiNetworkCallback() {
        ConnectivityManager cm = (ConnectivityManager) getSystemService(CONNECTIVITY_SERVICE);
        if (cm == null) {
            return;
        }
        NetworkRequest wifiLan = new NetworkRequest.Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                .build();
        cm.registerNetworkCallback(wifiLan, new CameraEth0WifiNetworkCallback());
    }

    /** Re-apply {@code eth0} when the camera cable is unplugged and plugged back in. */
    private void initCameraEth0LinkMonitor() {
        CameraEth0LinkMonitor.start();
    }

    /**
     * 系统参数设置
     */
    public void systemParamsSetting() {
        SystemSettingUtils.frontDeskGuardian();
        SystemSettingUtils.hideStatusBar();
        SystemSettingUtils.hideNavigationBar();
        SystemSettingUtils.enableLightMode();
        SystemSettingUtils.setCameraNetworkSegment(this);
    }
}
