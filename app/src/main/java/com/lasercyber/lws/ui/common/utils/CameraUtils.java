package com.lasercyber.lws.ui.common.utils;

import android.util.Log;

import androidx.annotation.NonNull;

import com.innohi.YNHAPI;
import com.lasercyber.lws.ui.common.camera.CameraPingHealth;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

/**
 * 摄像头工具 类
 */
public class CameraUtils {
    private static final String TAG = LogTAGConstant.CameraUtils;

    /**
     * Blocking camera communication probe using ICMP ping with a bounded timeout.
     */
    public static boolean checkCameraBlocking() {
        Log.d(TAG, "checkCameraBlocking: 开始检测摄像头（ping）");
        boolean reachable = CameraPingHealth.getInstance().probeBlocking();
        if (reachable) {
            Log.d(TAG, "checkCameraBlocking: 摄像头可用（ping 可达）");
            return true;
        }
        Log.w(TAG, "checkCameraBlocking: 摄像头不可用（ping 不可达）");
        try {
            if (!YNHAPI.getInstance().isEthernetOpen()) {
                Log.e(TAG, "checkCameraBlocking: 以太网没有打开");
            }
        } catch (Throwable ignored) {
        }
        return false;
    }

    public static void checkCamera(CheckCameraListener checkCameraListener) {
        Log.d(TAG, "checkCamera: 开始检测摄像头（ping）");
        Thread probeWait = new Thread(() -> {
            boolean reachable = CameraPingHealth.getInstance().probeBlocking();
            if (checkCameraListener == null) {
                return;
            }
            if (reachable) {
                Log.d(TAG, "checkCamera: 摄像头可用（ping 可达）");
                checkCameraListener.success();
                return;
            }
            Log.w(TAG, "checkCamera: 摄像头不可用（ping 不可达）");
            checkCameraListener.fail();
            try {
                if (!YNHAPI.getInstance().isEthernetOpen()) {
                    Log.e(TAG, "checkCamera: 以太网没有打开");
                }
            } catch (Throwable ignored) {
            }
        }, "camera-ping-check");
        probeWait.setDaemon(true);
        probeWait.start();
    }

    public interface CheckCameraListener {
        /** 检测成功 */
        void success();

        /** 检测失败 */
        void fail();
    }
}
