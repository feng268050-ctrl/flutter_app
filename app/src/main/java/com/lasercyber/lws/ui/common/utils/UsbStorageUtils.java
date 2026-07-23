package com.lasercyber.lws.ui.common.utils;

import android.content.Context;
import android.os.Build;
import android.os.storage.StorageManager;
import android.os.storage.StorageVolume;
import android.text.TextUtils;

import java.io.File;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;

public class UsbStorageUtils {
    /**
     * 获取所有已挂载的外部存储设备（包括 U 盘）
     */
    public static List<String> getExternalStoragePaths(Context context) {
        List<String> paths = new ArrayList<>();
        StorageManager storageManager = (StorageManager) context.getSystemService(Context.STORAGE_SERVICE);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            // Android 7.0+ 直接通过 StorageVolume 获取
            List<StorageVolume> volumes = storageManager.getStorageVolumes();
            for (StorageVolume volume : volumes) {
                // 判断是否为可移除存储（通常 U 盘是可移除的）
                if (volume.isRemovable()) {
                    // 获取挂载路径（需反射，因为 getPath() 是隐藏方法）
                    String path = getVolumePath(volume);
                    if (!TextUtils.isEmpty(path) && new File(path).exists()) {
                        paths.add(path);
                    }
                }
            }
        } else {
            // Android 7.0 以下通过反射获取
            try {
                Method getVolumeList = storageManager.getClass().getMethod("getVolumeList");
                Object[] volumes = (Object[]) getVolumeList.invoke(storageManager);
                if (volumes != null) {
                    for (Object volume : volumes) {
                        Method isRemovable = volume.getClass().getMethod("isRemovable");
                        boolean removable = (boolean) isRemovable.invoke(volume);
                        if (removable) {
                            Method getPath = volume.getClass().getMethod("getPath");
                            String path = (String) getPath.invoke(volume);
                            if (!TextUtils.isEmpty(path) && new File(path).exists()) {
                                paths.add(path);
                            }
                        }
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
        return paths;
    }

    /**
     * 获取 StorageVolume 的挂载路径（反射调用隐藏方法）
     */
    private static String getVolumePath(StorageVolume volume) {
        try {
            Method getPath = StorageVolume.class.getMethod("getPath");
            return (String) getPath.invoke(volume);
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        }
    }

    /**
     * 检查是否有 U 盘，并返回第一个 U 盘的路径
     */
    public static String getFirstUsbStoragePath(Context context) {
        List<String> externalPaths = getExternalStoragePaths(context);
        for (String path : externalPaths) {
            // U 盘路径通常包含 "usb"、"udisk" 等关键词（可根据设备调整）
            if (path.contains("usb") || path.contains("udisk") || path.contains("external")) {
                return path;
            }
        }
        return null; // 无 U 盘
    }

    /**
     * 创建视频存储目录（优先 U 盘，否则用内部存储）
     */
    public static String getVideoSavePath(Context context) {
        // 1. 检查是否有 U 盘
        String usbPath = getFirstUsbStoragePath(context);
        if (!TextUtils.isEmpty(usbPath)) {
            File usbVideoDir = new File(usbPath + "/LaserRecord");
            if (usbVideoDir.exists() || usbVideoDir.mkdirs()) {
                return usbVideoDir.getAbsolutePath();
            }
        }

        // 2. 无 U 盘，使用应用内部存储（无需权限）
        File internalDir = new File(context.getExternalFilesDir(null), "LaserRecord");
        if (internalDir.exists() || internalDir.mkdirs()) {
            return internalDir.getAbsolutePath();
        }

        return null; // 存储路径创建失败
    }
}
