package com.lasercyber.lws.ui.common.utils;

import android.Manifest;
import android.bluetooth.BluetoothAdapter;
import android.content.Context;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.NetworkInfo;
import android.net.wifi.WifiInfo;
import android.net.wifi.WifiManager;
import android.os.Build;
import android.os.SystemClock;
import android.provider.Settings;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatDelegate;
import androidx.core.app.ActivityCompat;

import com.blankj.utilcode.util.DeviceUtils;
import com.blankj.utilcode.util.LanguageUtils;
import com.blankj.utilcode.util.NetworkUtils;
import com.innohi.YNHAPI;
import com.lasercyber.lws.ui.bean.entity.dto.ConnectedWifiInfo;
import com.lasercyber.lws.ui.common.config.CameraConfig;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.constant.SystemSettingConstant;
import com.lasercyber.lws.ui.common.camera.CameraDeviceInfoCache;
import com.lasercyber.lws.ui.common.camera.CameraPingHealth;
import com.lasercyber.lws.ui.common.network.CameraEth0Configurator;
import com.lasercyber.lws.ui.common.network.CameraEth0WifiNetworkCallback;
import com.lasercyber.lws.ui.common.utils.AndroidEmulatorUtils;
import com.lasercyber.lws.ui.network.http.local.CameraLanHttpProxy;

import com.blankj.utilcode.util.Utils;

import java.io.IOException;
import java.io.InputStream;
import java.io.ByteArrayOutputStream;
import java.net.HttpURLConnection;
import java.net.InetAddress;
import java.net.URL;
import java.util.Arrays;
import java.util.Locale;
import java.util.TimeZone;

import org.apache.commons.net.ntp.NTPUDPClient;
import org.apache.commons.net.ntp.TimeInfo;

/**
 * 系统参数设置工具类
 */
public class SystemSettingUtils {
    private static final String TAG = LogTAGConstant.SystemSettingUtils;
    private static final Object CAMERA_ETH0_CONFIGURE_LOCK = new Object();
    private static final String[] PUBLIC_NTP_HOSTS = new String[]{
            "time.cloudflare.com",
            "time.windows.com",
            "time.aws.com",
            "time.apple.com",
            "ntp.tencent.com"
    };
    private static final String[] PUBLIC_TIMEZONE_APIS = new String[]{
            "https://ipapi.co/json/",
            "http://ip-api.com/json/?fields=status,timezone"
    };

    /**
     * 设置开机启动
     */
    public static void bootLaunchApk(){
        YNHAPI.getInstance().setBootLaunchApk(SystemSettingConstant.APP_PACKAGE_NAME, true);
    }

    /**
     * 前台守护
     */
    public static void frontDeskGuardian(){
        try {
            YNHAPI.getInstance().setForegroundAppKeepLive(SystemSettingConstant.APP_PACKAGE_NAME, 10);
        } catch (Throwable throwable) {
            Log.e(TAG, "frontDeskGuardian skipped: YNHAPI unavailable", throwable);
        }
    }
    public static void closeFrontDeskGuardian(){
        YNHAPI.getInstance().setForegroundAppKeepLive("", 1);
    }
    /**
     * 静默安装并启动APK
     * @param apkPath apk路径
     */
    public static void installApkSilently(String apkPath){
        YNHAPI.getInstance().installApkSilently(apkPath,SystemSettingConstant.APP_PACKAGE_NAME,SystemSettingConstant.APP_MAIN_ACTIVITY);
    }

    /**
     * 隐藏状态栏
     */
    public static void hideStatusBar(){
        try {
            YNHAPI.getInstance().setExtendStatusBarVisibility(YNHAPI.ExtendStatusBarVisibility.INVISIBLE_FOREVER);
        } catch (Throwable throwable) {
            Log.e(TAG, "hideStatusBar skipped: YNHAPI unavailable", throwable);
        }
    }
    /**
     * 显示状态栏
     */
    public static void showStatusBar(){
        YNHAPI.getInstance().setExtendStatusBarVisibility(YNHAPI.ExtendStatusBarVisibility.VISABLE_EXPAND);
    }
    /**
     * 隐藏导航栏
     */
    public static void hideNavigationBar(){
        try {
            YNHAPI.getInstance().setNavigationBarVisibility(YNHAPI.NavigationBarVisibility.ALWAYS_INVISIBLE);
        } catch (Throwable throwable) {
            Log.e(TAG, "hideNavigationBar skipped: YNHAPI unavailable", throwable);
        }
    }
    /**
     * 显示导航栏
     */
    public static void showNavigationBar(){
        YNHAPI.getInstance().setNavigationBarVisibility(YNHAPI.NavigationBarVisibility.VISIBLE);
    }

    /**
     * 切换到夜间模式
     */
    public static void enableDarkMode() {
        // 设置夜间模式为强制开启
        AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_YES);
        // 重启当前 Activity 使主题生效（API 30+ 可省略，自动刷新）
    }

    /**
     * 切换到浅色模式
     */
    public static void enableLightMode() {
        AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_NO);
    }

    /**
     * 跟随系统设置
     */
    public static void followSystemMode() {
        AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM);
    }

    /**
     *  以太网是否打开
     */
    public static boolean isEthernetOpen(){
        return YNHAPI.getInstance().isEthernetOpen();
    }

    /**
     * 打开以太网
     */
    public static void openEthernet(){
        try {
            YNHAPI.getInstance().setEthernetState(true);
        } catch (Throwable t) {
            Log.w(TAG, "openEthernet skipped: YNHAPI unavailable (e.g. missing innohi stubs on this build)", t);
        }
    }

    /**
     * 按摄像头 IP 配置 {@code eth0} 同网段地址，并避开当前 Wi-Fi（{@code wlan0}）IPv4。
     * Wi-Fi 地址来源与 Wi-Fi 详情页一致：{@link WifiStatusUtils#getConnectedWifiInfo}。
     */
    public static boolean setCameraNetworkSegment() {
        return setCameraNetworkSegment(Utils.getApp());
    }

    /**
     * Configures {@code eth0} for the camera /24. Returns whether address is set and the camera is reachable.
     *
     * @see CameraEth0Configurator
     */
    public static boolean setCameraNetworkSegment(@Nullable Context context) {
        if (context == null) {
            Log.w(TAG, "setCameraNetworkSegment skipped: no context");
            return false;
        }
        if (AndroidEmulatorUtils.isLikelyEmulator()) {
            Log.i(TAG, "setCameraNetworkSegment skipped on emulator (use tablet LAN camera proxy)");
            return true;
        }
        Context app = context.getApplicationContext();
        openEthernet();
        String cameraHost = CameraConfig.getCameraIp();
        ConnectedWifiInfo wifi = WifiStatusUtils.getConnectedWifiInfo(app);
        String wlanIp = wifi == null ? null : wifi.getIpAddress();
        synchronized (CAMERA_ETH0_CONFIGURE_LOCK) {
            if (CameraEth0Configurator.isSegmentHealthy(cameraHost, wlanIp)) {
                Log.i(TAG, "setCameraNetworkSegment skipped: eth0 segment already healthy");
                CameraEth0WifiNetworkCallback.noteWlanIpAtConfigure(wlanIp);
                return true;
            }
            try {
                CameraPingHealth.getInstance().beginEth0Configure();
                CameraEth0Configurator.Result result =
                        CameraEth0Configurator.configure(cameraHost, wlanIp);
                CameraEth0Configurator.logResult(result);
                CameraEth0WifiNetworkCallback.noteWlanIpAtConfigure(wlanIp);
                CameraPingHealth.getInstance().endEth0Configure(result.pingOk);
                if (result.success()) {
                    CameraDeviceInfoCache.refresh(app);
                    CameraLanHttpProxy.getInstance().ensureStarted(app);
                }
                return result.success();
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                CameraPingHealth.getInstance().endEth0Configure(false);
                Log.w(TAG, "setCameraNetworkSegment interrupted camera=" + cameraHost, e);
                return false;
            } catch (IOException e) {
                CameraPingHealth.getInstance().endEth0Configure(false);
                Log.w(TAG, "setCameraNetworkSegment failed camera=" + cameraHost, e);
                return false;
            }
        }
    }

    /**
     * 获取当前连接的WiFi名称（SSID）
     * @param context
     * @return
     */
    public static String getConnectedWifiName(Context context) {
        boolean wifiEnabled = NetworkUtils.getWifiEnabled();
        if (!wifiEnabled){
            return null;
        }
        // 检查权限（Android 13+ 需要位置权限）
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
                && ActivityCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION)
                != PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "获取WiFi名称需要ACCESS_FINE_LOCATION权限");
            return null;
        }

        WifiManager wifiManager = (WifiManager) context.getApplicationContext().getSystemService(Context.WIFI_SERVICE);
        if (wifiManager == null) return null;

        WifiInfo wifiInfo = wifiManager.getConnectionInfo();
        if (wifiInfo == null) return null;

        String ssid = wifiInfo.getSSID();
        // SSID可能包含双引号（如"WiFi名称"），去除引号
        if (ssid.startsWith("\"") && ssid.endsWith("\"")) {
            ssid = ssid.substring(1, ssid.length() - 1);
        }
        return ssid;
    }

    /**
     * 获取4G网络状态（是否连接）
     * @param context
     * @return
     */
    public static boolean is4GConnected(Context context) {
        ConnectivityManager cm = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
        if (cm == null) return false;

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            // Android 6.0+ 推荐用法
            Network network = cm.getActiveNetwork();
            if (network == null) return false;

            NetworkCapabilities capabilities = cm.getNetworkCapabilities(network);
            boolean isWifi = capabilities != null && capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)
                    && capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET);
            // 判断是否为移动网络（包含4G、5G等，这里主要检测4G）
            return isWifi;
        } else {
            // 旧版本兼容（API < 23）
            NetworkInfo networkInfo = cm.getNetworkInfo(ConnectivityManager.TYPE_MOBILE);
            return networkInfo != null && networkInfo.isConnected();
        }
    }

    /**
     * 判断蓝牙是否开启
     * @return true：蓝牙已开启；false：蓝牙未开启或设备不支持蓝牙
     */
    public static boolean isBluetoothEnabled() {
        // 获取系统蓝牙适配器（全局唯一）
        BluetoothAdapter bluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
        // 设备不支持蓝牙
        if (bluetoothAdapter == null) {
            return false;
        }
        // 判断蓝牙是否开启
        return bluetoothAdapter.isEnabled();
    }
    /**
     * 获取系统全局屏幕亮度（0~255）
     * @param context 上下文
     * @return 亮度值（-1 表示获取失败）
     */
    public static int getSystemBrightness(Context context) {
        try {
            // 通过 Settings.System 获取系统亮度
            return Settings.System.getInt(
                    context.getContentResolver(),
                    Settings.System.SCREEN_BRIGHTNESS
            );
        } catch (Settings.SettingNotFoundException e) {
            Log.d(TAG, "getSystemBrightness: 获取设备屏幕亮度失败");
            return -1; // 获取失败
        }
    }
    /**
     * 获取系统息屏时间（自动锁屏时长，单位：毫秒）
     * @param context 上下文
     * @return 息屏时间（毫秒），-1 表示获取失败
     */
    public static int getScreenTimeout(Context context) {
        try {
            // 从系统设置中查询 SCREEN_OFF_TIMEOUT 字段
            return Settings.System.getInt(
                    context.getContentResolver(),
                    Settings.System.SCREEN_OFF_TIMEOUT
            );
        } catch (Settings.SettingNotFoundException e) {
            Log.d(TAG, "getScreenTimeout: 获取系统息屏时间异常",e);
            return -1; // 获取失败（如设备不支持该设置）
        }
    }
    /**
     * 判断当前是否处于暗色模式（兼容应用内主题设置）
     * @param context 上下文
     * @return true：暗色模式；false：浅色模式
     */
    public static boolean isDarkModeCompat(Context context) {
        // 获取当前应用的夜间模式设置
        int nightMode = AppCompatDelegate.getDefaultNightMode();
        if (nightMode == AppCompatDelegate.MODE_NIGHT_YES) {
            // 应用强制暗色模式
            return true;
        } else if (nightMode == AppCompatDelegate.MODE_NIGHT_NO) {
            // 应用强制浅色模式
            return false;
        } else {
            // 跟随系统模式，使用系统配置判断
            Configuration config = context.getResources().getConfiguration();
            int systemNightMode = config.uiMode & Configuration.UI_MODE_NIGHT_MASK;
            return systemNightMode == Configuration.UI_MODE_NIGHT_YES;
        }
    }
    /**
     * 修改系统全局屏幕亮度
     * @param context 上下文
     * @param brightness 亮度值（0~255）
     */
    public static void setSystemBrightness(Context context, int brightness) {
        // 亮度值限制在 0~255 之间
        if (brightness < 0) brightness = 0;
        if (brightness > 255) brightness = 255;

        try {
            // 1. 关闭自动亮度（否则手动设置可能无效）
            Settings.System.putInt(
                    context.getContentResolver(),
                    Settings.System.SCREEN_BRIGHTNESS_MODE,
                    Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL
            );

            // 2. 设置系统亮度值
            Settings.System.putInt(
                    context.getContentResolver(),
                    Settings.System.SCREEN_BRIGHTNESS,
                    brightness
            );
        } catch (Exception e) {
            Log.d(TAG, "setSystemBrightness: 修改屏幕亮度异常",e);
        }
    }

    /**
     * 获取系统版本
     * @return
     */
    public static String getSystemVersion() {
        return "Android "+DeviceUtils.getSDKVersionName();
    }

    /**
     * 获取语言
     * @return
     */
    public static Locale getLanguage(){
        Locale language = LanguageUtils.getAppliedLanguage();
        if (language!=null){
            return language;
        }
        return  LanguageUtils.getSystemLanguage();
    }

    /**
     * 设置启动动画
     */
    public static void setBootAnimation() {
        YNHAPI.getInstance().setBootAnimation("/sdcard/boot/bootanimation.zip");
    }

    public static boolean isAutoTimeEnabled(Context context) {
        return Settings.Global.getInt(context.getContentResolver(), Settings.Global.AUTO_TIME, 0) == 1;
    }

    public static boolean setAutoTimeEnabled(Context context, boolean enabled) {
        try {
            return Settings.Global.putInt(
                    context.getContentResolver(),
                    Settings.Global.AUTO_TIME,
                    enabled ? 1 : 0
            );
        } catch (Exception exception) {
            Log.e(TAG, "setAutoTimeEnabled failed", exception);
            return false;
        }
    }

    public static boolean isAutoTimeZoneEnabled(Context context) {
        return Settings.Global.getInt(context.getContentResolver(), Settings.Global.AUTO_TIME_ZONE, 0) == 1;
    }

    public static boolean setAutoTimeZoneEnabled(Context context, boolean enabled) {
        try {
            return Settings.Global.putInt(
                    context.getContentResolver(),
                    Settings.Global.AUTO_TIME_ZONE,
                    enabled ? 1 : 0
            );
        } catch (Exception exception) {
            Log.e(TAG, "setAutoTimeZoneEnabled failed", exception);
            return false;
        }
    }

    public static boolean setDateAndTimeMillis(Context context, long dateTimeMillis) {
        try {
            android.app.AlarmManager alarmManager =
                    (android.app.AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
            if (alarmManager == null) {
                return false;
            }
            alarmManager.setTime(dateTimeMillis);
            return true;
        } catch (Exception exception) {
            Log.e(TAG, "setDateAndTimeMillis failed", exception);
            return false;
        }
    }

    public static boolean setTimeZone(Context context, String timeZoneId) {
        try {
            android.app.AlarmManager alarmManager =
                    (android.app.AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
            if (alarmManager == null) {
                return false;
            }
            alarmManager.setTimeZone(timeZoneId);
            return true;
        } catch (Exception exception) {
            Log.e(TAG, "setTimeZone failed", exception);
            return false;
        }
    }

    public static String[] getAvailableTimeZoneIds() {
        String[] ids = TimeZone.getAvailableIDs();
        Arrays.sort(ids);
        return ids;
    }

    public static String getCurrentTimeZoneId() {
        return TimeZone.getDefault().getID();
    }

    public static boolean isNetworkConnected(Context context) {
        ConnectivityManager cm = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
        if (cm == null) {
            return false;
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Network network = cm.getActiveNetwork();
            if (network == null) {
                return false;
            }
            NetworkCapabilities capabilities = cm.getNetworkCapabilities(network);
            return capabilities != null && capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET);
        }
        NetworkInfo info = cm.getActiveNetworkInfo();
        return info != null && info.isConnected();
    }

    public static boolean syncDateTimeFromPublicNtp(Context context) {
        for (String host : PUBLIC_NTP_HOSTS) {
            NTPUDPClient client = new NTPUDPClient();
            client.setDefaultTimeout(3000);
            try {
                InetAddress address = InetAddress.getByName(host);
                TimeInfo timeInfo = client.getTime(address);
                long networkTime = timeInfo.getMessage().getTransmitTimeStamp().getTime();
                long now = System.currentTimeMillis();
                long elapsedRealtime = SystemClock.elapsedRealtime();
                // Compensate query transit time with elapsed real-time delta before applying.
                long adjusted = networkTime + (SystemClock.elapsedRealtime() - elapsedRealtime);
                boolean ok;
                if (Math.abs(adjusted - now) < 1500L) {
                    ok = true;
                } else {
                    ok = setDateAndTimeMillis(context, adjusted);
                }
                if (ok) {
                    Log.i(TAG, "NTP sync succeeded with host: " + host);
                    return true;
                }
                Log.w(TAG, "NTP sync rejected by platform with host: " + host);
            } catch (Throwable exception) {
                Log.e(TAG, "NTP sync failed for host: " + host, exception);
            } finally {
                client.close();
            }
        }
        return false;
    }

    public static boolean syncTimeZoneFromPublicService(Context context) {
        for (String endpoint : PUBLIC_TIMEZONE_APIS) {
            HttpURLConnection connection = null;
            InputStream inputStream = null;
            try {
                URL url = new URL(endpoint);
                connection = (HttpURLConnection) url.openConnection();
                connection.setRequestMethod("GET");
                connection.setConnectTimeout(8000);
                connection.setReadTimeout(8000);
                if (connection.getResponseCode() != 200) {
                    continue;
                }
                inputStream = connection.getInputStream();
                byte[] bytes = readAllBytesCompat(inputStream);
                String body = new String(bytes);
                String timezone = parseTimezoneFromResponse(body);
                if (timezone.isEmpty()) {
                    continue;
                }
                if (setTimeZone(context, timezone)) {
                    Log.i(TAG, "Timezone sync succeeded with endpoint: " + endpoint + ", timezone=" + timezone);
                    return true;
                }
                Log.w(TAG, "Timezone sync rejected by platform for endpoint: " + endpoint + ", timezone=" + timezone);
            } catch (Throwable exception) {
                Log.e(TAG, "syncTimeZoneFromPublicService failed for " + endpoint, exception);
            } finally {
                if (inputStream != null) {
                    try {
                        inputStream.close();
                    } catch (IOException ignored) {
                    }
                }
                if (connection != null) {
                    connection.disconnect();
                }
            }
        }
        return false;
    }

    private static String parseTimezoneFromResponse(String body) {
        if (body == null || body.isEmpty()) {
            return "";
        }
        String marker = "\"timezone\":\"";
        int start = body.indexOf(marker);
        if (start >= 0) {
            start += marker.length();
            int end = body.indexOf("\"", start);
            if (end > start) {
                return body.substring(start, end);
            }
        }
        String markerAlt = "\"timeZone\":\"";
        start = body.indexOf(markerAlt);
        if (start >= 0) {
            start += markerAlt.length();
            int end = body.indexOf("\"", start);
            if (end > start) {
                return body.substring(start, end);
            }
        }
        return "";
    }

    private static byte[] readAllBytesCompat(InputStream inputStream) throws IOException {
        ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
        byte[] buffer = new byte[4096];
        int read;
        while ((read = inputStream.read(buffer)) != -1) {
            outputStream.write(buffer, 0, read);
        }
        return outputStream.toByteArray();
    }
}
