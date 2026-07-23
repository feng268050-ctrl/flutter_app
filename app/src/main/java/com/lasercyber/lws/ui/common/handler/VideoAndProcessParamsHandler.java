package com.lasercyber.lws.ui.common.handler;

import android.graphics.Bitmap;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import com.blankj.utilcode.util.GsonUtils;
import com.lasercyber.lws.ui.bean.entity.VideoInfo;
import com.lasercyber.lws.ui.bean.http.ProcessParamsVideo;
import com.lasercyber.lws.ui.bean.http.ProcessVideo;
import com.lasercyber.lws.ui.bean.result.Result;
import com.lasercyber.lws.ui.bean.ui.SubmitProcessDataAndVideo;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.config.DeviceApiOriginConfig;
import com.lasercyber.lws.ui.common.device.DeviceIdentity;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.enums.UploadFileType;
import com.lasercyber.lws.ui.common.oss.OSSAsyncResumableUploadFail;
import com.lasercyber.lws.ui.common.oss.ObjectStorageUrls;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.utils.VideoFileUtils;
import com.lasercyber.lws.ui.common.utils.convert.VideoInfoConvert;
import com.lasercyber.lws.ui.network.http.RequestApi;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.util.Objects;
import java.util.UUID;

import retrofit2.Call;
import retrofit2.Callback;
import retrofit2.Response;

/**
 * 录制视频上传链路：历史上用于「录制完成后立即上传」（由 {@link com.lasercyber.lws.ui.component.CameraController}
 * 在停止录制后弹窗确认标题并触发上传）；现已移除录制完成后的确认上传弹窗与自动上传，仅保留显式入口（例如
 * {@link com.lasercyber.lws.ui.activitys.dev.DevActivity} 调试入口、Monitor 列表补传等）。
 * 封面与视频均为 R2 STS + S3。Monitor 列表补传见 {@link MonitorProcessVideoListUploadRunner}。
 */
public class VideoAndProcessParamsHandler {
    private static final String TAG = LogTAGConstant.VideoAndProcessParamsHandler;
    private static final Handler handler = new Handler(Looper.getMainLooper());
    private static Runnable task;

    private static final Object UPLOAD_NETWORK_LOCK = new Object();
    private static volatile Call<?> activeProcessVideoUploadCall;

    private static void clearAllTask() {
        if (task != null) {
            handler.removeCallbacks(task);
        }
        task = null;
        MemoryCacheManager.getInstance().remove(CacheKey.UPLOADING_VIDEO_MARK);
    }

    /** Best-effort cancel for in-flight Retrofit metadata registration. */
    public static void cancelActiveUpload() {
        synchronized (UPLOAD_NETWORK_LOCK) {
            Call<?> c = activeProcessVideoUploadCall;
            if (c != null) {
                c.cancel();
            }
            activeProcessVideoUploadCall = null;
        }
        clearAllTask();
    }

    private static void clearActiveProcessVideoCall(Call<?> call) {
        synchronized (UPLOAD_NETWORK_LOCK) {
            if (activeProcessVideoUploadCall == call) {
                activeProcessVideoUploadCall = null;
            }
        }
    }

    private static void markTask(OSSAsyncResumableUploadFail ossAsyncResumableUploadFail) {
        task = () -> {
            Boolean uploadingVideo = MemoryCacheManager.getInstance().getSerializable(CacheKey.UPLOADING_VIDEO_MARK);
            if (Objects.equals(uploadingVideo, Boolean.TRUE)) {
                Log.d(TAG, "markTask: 视频正在上传中，再次加入延迟任务");
                handler.postDelayed(task, 1000 * 60 * 2);
                return;
            }
            Log.e(TAG, "markTask: 上传超时");
            ossAsyncResumableUploadFail.onFailure(null, new Exception("上传超时"), null, UploadFileType.NONE);
        };
        handler.postDelayed(task, 1000 * 60 * 2);
    }

    /** 录制完成后的首次上传：R2 STS 封面 → 元数据 POST → R2 STS 视频。 */
    public static void saveVideoAndProcessParams(SubmitProcessDataAndVideo submitProcessDataAndVideo) {
        if (submitProcessDataAndVideo.getProcessParametersData() == null) {
            submitProcessDataAndVideo.getOssAsyncResumableUploadFail()
                    .onFailure(null, new Exception("工艺参数为空"), null, UploadFileType.NONE);
            return;
        }
        String sn = DeviceIdentity.getDeviceSnSafely().trim();
        if (sn.isEmpty() || "unknown-sn".equals(sn)) {
            submitProcessDataAndVideo.getOssAsyncResumableUploadFail()
                    .onFailure(null, new Exception("无效设备序列号"), null, UploadFileType.NONE);
            return;
        }
        markTask(submitProcessDataAndVideo.getOssAsyncResumableUploadFail());
        VideoInfo videoInfo = VideoFileUtils.readVideoFileInfo(submitProcessDataAndVideo.getVideoPath());
        if (videoInfo == null) {
            clearAllTask();
            submitProcessDataAndVideo.getOssAsyncResumableUploadFail()
                    .onFailure(null, new Exception("未找到文件"), null, UploadFileType.NONE);
            return;
        }
        if (!ObjectStorageUrls.checkVideoSize(videoInfo.getFileSize())) {
            clearAllTask();
            Log.d(TAG, "视频文件过大：" + videoInfo.getFileSize() + ",fileName:" + videoInfo.getFileName());
            submitProcessDataAndVideo.getOssAsyncResumableUploadFail()
                    .onFailure(null, new Exception("视频文件过大"), null, UploadFileType.NONE);
            return;
        }

        ThreadPoolManager.getExecutor().execute(() -> {
            long pathDateMs = 0L;
            if (videoInfo.getRecordingTime() != null) {
                pathDateMs = videoInfo.getRecordingTime().getTime();
            }
            if (pathDateMs <= 0L) {
                pathDateMs = new File(submitProcessDataAndVideo.getVideoPath()).lastModified();
            }
            String dateStr = ProcessVideoUploadR2Keys.yyyyMmDdFromEpochMillis(pathDateMs);

            if (videoInfo.getCoverBitmap() == null) {
                Log.e(TAG, "cover bitmap null");
                handler.post(() -> {
                    clearAllTask();
                    submitProcessDataAndVideo.getOssAsyncResumableUploadFail()
                            .onFailure(null, new Exception("封面数据为空"), null, UploadFileType.IMAGE);
                });
                return;
            }
            if (DeviceApiOriginConfig.getPinnedBase() == null) {
                handler.post(() -> {
                    clearAllTask();
                    submitProcessDataAndVideo.getOssAsyncResumableUploadFail()
                            .onFailure(null, new Exception("未选择 Worker API 地址"), null, UploadFileType.IMAGE);
                });
                return;
            }
            byte[] coverJpeg = compressCoverJpeg(videoInfo.getCoverBitmap());
            if (coverJpeg == null || coverJpeg.length == 0) {
                Log.e(TAG, "cover jpeg empty");
                handler.post(() -> {
                    clearAllTask();
                    submitProcessDataAndVideo.getOssAsyncResumableUploadFail()
                            .onFailure(null, new Exception("封面数据为空"), null, UploadFileType.IMAGE);
                });
                return;
            }
            final String sessionVideoId = UUID.randomUUID().toString();
            String coverObjectKey = ProcessVideoUploadR2Keys.videoObjectKey(sn, dateStr, sessionVideoId, "jpg");
            String imageUrl;
            try {
                imageUrl = ProcessVideoR2CoverUpload.putCoverJpegAndPublicUrl(sn, coverObjectKey, coverJpeg);
            } catch (IOException e) {
                Log.e(TAG, "R2 cover upload failed", e);
                handler.post(() -> {
                    clearAllTask();
                    String msg = e.getMessage() != null ? e.getMessage() : "封面上传失败";
                    submitProcessDataAndVideo.getOssAsyncResumableUploadFail()
                            .onFailure(null, new Exception(msg), null, UploadFileType.IMAGE);
                });
                return;
            }

            ProcessVideo processVideo = VideoInfoConvert.convertToProcessVideo(videoInfo, imageUrl);
            if (submitProcessDataAndVideo.getProcessParametersData() != null) {
                processVideo.setProcessType(submitProcessDataAndVideo.getProcessParametersData().getProcessType());
            }

            String videoBaseName = new File(videoInfo.getFileName()).getName();
            String videoContentType = guessVideoContentType(videoBaseName);
            String videoExt = ProcessVideoUploadR2Keys.videoExtFromPath(videoBaseName);
            String videoObjectKey = ProcessVideoUploadR2Keys.videoObjectKey(sn, dateStr, sessionVideoId, videoExt);
            String videoPublicUrl = ProcessVideoR2PublicUrls.publicAssetUrlFromCoverPublicUrl(imageUrl, videoObjectKey);
            processVideo.setVideoUrl(videoPublicUrl);

            ProcessParamsVideo processParamsVideo = new ProcessParamsVideo(
                    submitProcessDataAndVideo.getProcessParametersData(), processVideo);
            processParamsVideo.setVideoTitle(submitProcessDataAndVideo.getVideoTitle());
            Log.d(TAG, "准备提交数据到服务器：" + GsonUtils.toJson(processParamsVideo));

            Call<Result<Long>> retrofitCall = RequestApi.getProcessVideoRemote()
                    .uploadVideoAndProcessData(processParamsVideo);
            synchronized (UPLOAD_NETWORK_LOCK) {
                activeProcessVideoUploadCall = retrofitCall;
            }
            retrofitCall.enqueue(new Callback<Result<Long>>() {
                @Override
                public void onResponse(Call<Result<Long>> call, Response<Result<Long>> response) {
                    clearActiveProcessVideoCall(call);
                    if (!response.isSuccessful()) {
                        clearAllTask();
                        submitProcessDataAndVideo.getOssAsyncResumableUploadFail()
                                .onFailure(null, new Exception("提交参数失败 http " + response.code()),
                                        null, UploadFileType.VIDEO);
                        return;
                    }
                    Result<Long> body = response.body();
                    if (body == null || !body.isSuccess()) {
                        clearAllTask();
                        String m = body != null ? body.getMsg() : "empty body";
                        submitProcessDataAndVideo.getOssAsyncResumableUploadFail()
                                .onFailure(null, new Exception(m != null ? m : "提交参数失败"),
                                        null, UploadFileType.VIDEO);
                        return;
                    }
                    Long videoId = body.getData();
                    uploadVideoToR2StsS3Put(submitProcessDataAndVideo, submitProcessDataAndVideo.getVideoPath(),
                            sn, videoObjectKey, videoContentType, videoId);
                }

                @Override
                public void onFailure(Call<Result<Long>> call, Throwable t) {
                    clearActiveProcessVideoCall(call);
                    clearAllTask();
                    submitProcessDataAndVideo.getOssAsyncResumableUploadFail()
                            .onFailure(null, new Exception("提交参数失败", t), null, UploadFileType.VIDEO);
                }
            });
        });
    }

    private static byte[] compressCoverJpeg(Bitmap bitmap) {
        if (bitmap == null) {
            return null;
        }
        try (ByteArrayOutputStream baos = new ByteArrayOutputStream()) {
            if (!bitmap.compress(Bitmap.CompressFormat.JPEG, 90, baos)) {
                return null;
            }
            return baos.toByteArray();
        } catch (IOException e) {
            return null;
        }
    }

    private static void uploadVideoToR2StsS3Put(
            SubmitProcessDataAndVideo submitProcessDataAndVideo,
            String localVideoPath,
            String snTrimmed,
            String videoObjectKey,
            String videoContentType,
            Long videoId
    ) {
        ThreadPoolManager.getExecutor().execute(() -> {
            MemoryCacheManager.getInstance().putSerializableNoNotice(CacheKey.UPLOADING_VIDEO_MARK, Boolean.TRUE);
            try {
                ProcessVideoR2StsVideoPut.putLocalFile(
                        snTrimmed,
                        new File(localVideoPath),
                        videoObjectKey,
                        videoContentType,
                        (read, total) -> {
                            if (submitProcessDataAndVideo.getOssProgressCallback() != null) {
                                handler.post(() -> submitProcessDataAndVideo.getOssProgressCallback()
                                        .onProgress(null, read, total, UploadFileType.VIDEO));
                            }
                        });
                handler.post(() -> {
                    clearAllTask();
                    if (submitProcessDataAndVideo.getOssAsyncResumableUploadSuccess() != null) {
                        submitProcessDataAndVideo.getOssAsyncResumableUploadSuccess()
                                .onSuccess(null, null, UploadFileType.VIDEO);
                    }
                });
            } catch (Exception e) {
                Log.e(TAG, "R2 STS video put failed videoId=" + videoId, e);
                handler.post(() -> {
                    clearAllTask();
                    submitProcessDataAndVideo.getOssAsyncResumableUploadFail()
                            .onFailure(null, e, null, UploadFileType.VIDEO);
                });
            }
        });
    }

    private static String guessVideoContentType(String fileName) {
        if (fileName == null) {
            return "application/octet-stream";
        }
        String lower = fileName.toLowerCase();
        if (lower.endsWith(".mp4")) {
            return "video/mp4";
        }
        if (lower.endsWith(".webm")) {
            return "video/webm";
        }
        if (lower.endsWith(".3gp")) {
            return "video/3gpp";
        }
        if (lower.endsWith(".mkv")) {
            return "video/x-matroska";
        }
        return "application/octet-stream";
    }
}
