package com.lasercyber.lws.ui.common.sysservice;

import android.app.Service;
import android.content.Intent;
import android.os.IBinder;
import android.util.Log;

import androidx.annotation.Nullable;

import com.blankj.utilcode.util.StringUtils;
import com.lasercyber.lws.ui.common.config.CameraConfig;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.sysservice.video.BackgroundLoopRecorder;
import com.lasercyber.lws.ui.common.sysservice.video.UsbMountReceiver;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.utils.UsbStorageUtils;
import com.lasercyber.lws.ui.common.utils.VideoFileUtil;


/**
 * 后台录制视频
 */
public class RecordService extends Service {
    private static final String TAG = LogTAGConstant.RecordService;
    private BackgroundLoopRecorder loopRecorder;

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public void onCreate() {
        super.onCreate();
        // 初始化存储路径（优先 U 盘）
        String videoSaveDir = UsbStorageUtils.getFirstUsbStoragePath(this);
        if (StringUtils.isEmpty(videoSaveDir)){
            // 设置为默认的存储路径
            videoSaveDir=CameraConfig.DEFAULT_VIDEO_SAVE_PATH;
        }else {
            videoSaveDir+=CameraConfig.APP_PATH;
        }
        Log.d(TAG, "onCreate: 存储路径检测结果=====>"+videoSaveDir);
        VideoFileUtil.setPath(videoSaveDir);
        // 注册 U 盘状态监听（可选，用于动态切换路径）
        UsbMountReceiver receiver = new UsbMountReceiver(new UsbMountReceiver.OnUsbStateChangeListener() {
            @Override
            public void onUsbMounted(String usbPath) {
                // U 盘插入，切换存储路径
                VideoFileUtil.setPath(usbPath+CameraConfig.APP_PATH);
                // 重启录制，使用新路径
                if(loopRecorder!=null){
                    loopRecorder.restartRecording();
                }
            }

            @Override
            public void onUsbUnmounted() {
                // U 盘拔出，切换到内部存储
                VideoFileUtil.setPath(CameraConfig.DEFAULT_VIDEO_SAVE_PATH);
                if(loopRecorder!=null){
                    loopRecorder.restartRecording();
                }
            }
        });
        // 注册监听
        ThreadPoolManager.getExecutor().execute(()-> receiver.register(this));
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        if (loopRecorder!=null){
            loopRecorder.stopLoopRecording();
        }
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        ThreadPoolManager.getExecutor().execute(()->{
            loopRecorder= new BackgroundLoopRecorder(this);
            boolean start = loopRecorder.start();
            if (!start) {
                Log.d(TAG, "onStartCommand: 后台录制视频启动失败");
            }
        });
        return START_STICKY;
    }
}
