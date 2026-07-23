package com.lasercyber.lws.ui.common.sysservice.video;

import android.content.Context;
import android.graphics.SurfaceTexture;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.Surface;

import com.lasercyber.lws.ui.common.config.CameraConfig;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.utils.VideoFileUtil;
import com.lasercyber.lws.ui.network.mediamtx.MediaMtxRelayCoordinator;
import com.lasercyber.lws.ui.network.mediamtx.MediaMtxRelayUrls;

import org.easydarwin.video.Client;
import org.easydarwin.video.EasyPlayerClient;

import java.util.Date;

import cn.hutool.core.date.DateUtil;
import lombok.Setter;

/**
 * 后台录制视频逻辑
 */
public class BackgroundLoopRecorder {
    private static final String TAG = LogTAGConstant.BackgroundLoopRecorder;
    private final Context context;
    private EasyPlayerClient client;
    private Surface virtualSurface;
    private final Handler mainHandler;
    private Runnable stopCurrentRunnable; // 用于当前视频的1分钟超时停止
    private volatile boolean isLooping = false; // 是否处于循环录制状态
    // 文件路径
    private String path;
    // 视频时长（分钟）
    @Setter
    private int recordDuration = CameraConfig.DEFAULT_VIDEO_DURATION;


    public BackgroundLoopRecorder(Context context) {
        this.context = context;
        this.mainHandler = new Handler(Looper.getMainLooper());
    }

    public boolean start() {
        Log.d(TAG, "start: 正在启动定时录制视频");
        if (client != null) {
            Log.e(TAG, "start: 请勿重复启动后台录制");
            return false;
        }
        // 初始化虚拟Surface和播放器
        virtualSurface = createVirtualSurface();
        client = new EasyPlayerClient(context, virtualSurface, null);
        if (!MediaMtxRelayCoordinator.getInstance().isRelayReady()) {
            Log.w(TAG, "start: relay_not_ready");
            releaseResources();
            return false;
        }
        if (!MediaMtxRelayCoordinator.getInstance().acquireLease()) {
            Log.w(TAG, "start: relay extra lease failed");
            releaseResources();
            return false;
        }
        isLooping = true;
        // 开始录制
        return startRecorderVideo();
    }

    /**
     * 开始录制
     */
    public boolean startRecorderVideo() {
        if (!isLooping) {
            Log.w(TAG, "startRecorderVideo: 停止录制");
            return false;
        }
        try {
            // 启动当前视频录制
            int transportMode = Client.TRANSTYPE_TCP; // 根据实际流类型调整
            String toDay = DateUtil.format(new Date(), "yyyy-MM-dd");
            path = VideoFileUtil.getMovieName(toDay).getPath();
            Log.d(TAG, "startRecorderVideo: 正在录制视频，存储到：" + path);
            String recordUrl = MediaMtxRelayUrls.localPr0();
            Log.i(TAG, "RECORD_RTSP loop url=" + recordUrl + " profile=main");
            client.start(
                    recordUrl,
                    transportMode,
                    0,
                    Client.EASY_SDK_VIDEO_FRAME_FLAG | Client.EASY_SDK_AUDIO_FRAME_FLAG,
                    "", "",
                    path
            );
            // 开始录制
//            client.startRecord(path);
            // 3. 设置1分钟后自动停止当前视频，并启动下一个
            stopCurrentRunnable = () -> {
                if (isLooping) {
                    // 保存视频
                    client.stopRecord();
                    // 回调当前视频录制完成
                    if (loopListener != null) {
                        loopListener.onRecordCompleted(path);
                    }
                    // 启动下一个视频录制
                    startRecorderVideo();
                }
            };
            mainHandler.postDelayed(stopCurrentRunnable, recordDuration * 60 * 1000L); // 延迟再次触发
            // 回调当前视频开始录制
            if (loopListener != null) {
                loopListener.onRecordStarted(path);
            }
        } catch (Exception exception) {
            Log.e(TAG, "startRecorderVideo: 后台自动录制视频异常", exception);
            // 录制启动失败，停止循环
            isLooping = false;
            if (loopListener != null) {
                loopListener.onRecordFailed("启动失败：" + exception.getMessage());
            }
            return false;
        }
        return true;
    }


    /**
     * 停止循环录制（终止所有后续录制）
     */
    public void stopLoopRecording() {
        isLooping = false;
        stopRecording(); // 停止当前正在录制的视频
    }


    // 终止录制
    private void stopRecording() {
        // 取消当前视频的超时定时器
        if (stopCurrentRunnable != null) {
            mainHandler.removeCallbacks(stopCurrentRunnable);
            stopCurrentRunnable = null;
        }
        // 停止录制并释放资源
        releaseResources();
        // 回调当前视频被手动停止
        if (loopListener != null && path != null) {
            loopListener.onRecordStopped(path);
        }
        path = null;
    }

    // 释放播放器和Surface资源
    private void releaseResources() {
        if (client != null) {
            client.stopRecord();
            client.stop();
            client = null;
            MediaMtxRelayCoordinator.getInstance().releaseLease(); // extra lease only; LAN preview stays up
        }
        if (virtualSurface != null) {
            virtualSurface.release();
            virtualSurface = null;
        }
    }

    // 创建虚拟Surface（不渲染画面）
    private Surface createVirtualSurface() {
        SurfaceTexture virtualTexture = new SurfaceTexture(0);
        virtualTexture.setDefaultBufferSize(CameraConfig.VIDEO_RESOLUTION_WIDTH, CameraConfig.VIDEO_RESOLUTION_HEIGHT); // 设置默认分辨率
        return new Surface(virtualTexture);
    }

    /**
     * 重新录制
     */
    public void restartRecording() {
        Log.d(TAG, "restartRecording: 正在重新录制===>");
        isLooping = false;
        if (client != null) {
            // 停止上一次录制
            client.stopRecord();
            // 重新启动
            startRecorderVideo();
        } else {
            // 重新初始化
            releaseResources();
            start();
        }
    }

    // 循环录制回调接口
    public interface LoopRecordListener {
        void onRecordStarted(String filePath); // 单个视频开始录制

        void onRecordCompleted(String filePath); // 单个视频录制完成（1分钟超时）

        void onRecordStopped(String filePath); // 单个视频被手动停止

        void onRecordFailed(String errorMsg); // 录制失败
    }

    private LoopRecordListener loopListener;

    public void setLoopRecordListener(LoopRecordListener listener) {
        this.loopListener = listener;
    }

}
