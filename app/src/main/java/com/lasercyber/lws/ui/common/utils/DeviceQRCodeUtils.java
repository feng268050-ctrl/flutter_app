package com.lasercyber.lws.ui.common.utils;

import android.content.Context;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;

import com.blankj.utilcode.util.SizeUtils;
import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.BuildConfig;
import com.lasercyber.lws.ui.common.config.DeviceModelConfig;
import com.lasercyber.lws.ui.common.device.DeviceIdentity;
import com.lasercyber.lws.ui.common.utils.qrcode.QRCodeGenerator;

/**
 * 二维码生成
 */
public class DeviceQRCodeUtils {
    /**
     * 分隔符
     */
    public static final String DELIMITER = "|";

    /**
     * V2 格式版本号（明文段）
     */
    public static final String FORMAT_VERSION_V2 = "2";

    /**
     * 生成设备身份的二维码 v1
     *
     * @param width  dp
     * @param height dp
     * @return
     */
    public static Bitmap createDeviceIdentityQrCodeV1(int width, int height) {
        return QRCodeGenerator.generateQRCode(deviceQrCodeContent("1"), SizeUtils.dp2px(width), SizeUtils.dp2px(height));
    }

    /**
     * 生成设备身份的二维码 v2：{@code SN|2|Model|SystemVersion}
     *
     * @param width  dp
     * @param height dp
     */
    public static Bitmap createDeviceIdentityQrCodeV2(int width, int height) {
        return QRCodeGenerator.generateQRCode(deviceQrCodeContentV2(), SizeUtils.dp2px(width), SizeUtils.dp2px(height));
    }

    /**
     * V2 二维码文本（各字段中的 {@link #DELIMITER} 会替换为 {@code _}）
     */
    public static String deviceQrCodeContentV2() {
        return buildDeviceIdentityQrV2Text(
                DeviceIdentity.getDeviceSnSafely(),
                DeviceModelConfig.getModel(),
                resolveInstalledVersionName(Utils.getApp()));
    }

    /**
     * 组装 V2 明文（与 {@link #deviceQrCodeContentV2()} 相同规则，便于测试）
     */
    public static String buildDeviceIdentityQrV2Text(String sn, String model, String systemVersion) {
        return sanitizeQrField(sn) + DELIMITER + FORMAT_VERSION_V2 + DELIMITER + sanitizeQrField(model) + DELIMITER + sanitizeQrField(systemVersion);
    }

    /**
     * 禁止分隔符出现在载荷段内，避免扫码解析歧义。
     */
    public static String sanitizeQrField(String value) {
        if (value == null) {
            return "";
        }
        return value.replace('|', '_');
    }

    private static String deviceQrCodeContent(String version) {
        return sanitizeQrField(DeviceIdentity.getDeviceSnSafely()) + DELIMITER + version;
    }

    private static String resolveInstalledVersionName(Context context) {
        if (context == null) {
            return BuildConfig.VERSION_NAME != null ? BuildConfig.VERSION_NAME : "";
        }
        try {
            PackageInfo packageInfo = context.getPackageManager().getPackageInfo(context.getPackageName(), 0);
            String versionName = packageInfo.versionName;
            return versionName != null ? versionName : "";
        } catch (PackageManager.NameNotFoundException e) {
            return BuildConfig.VERSION_NAME != null ? BuildConfig.VERSION_NAME : "";
        }
    }
}
