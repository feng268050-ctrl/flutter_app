package com.lasercyber.lws.ui.activitys.dev;

import android.app.Activity;
import android.os.Handler;

import com.blankj.utilcode.util.ToastUtils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.bean.ui.SubmitProcessDataAndVideo;
import com.lasercyber.lws.ui.common.camera.EasyPlayerClientManger;
import com.lasercyber.lws.ui.common.enums.UploadFileType;
import com.lasercyber.lws.ui.common.handler.VideoAndProcessParamsHandler;
import com.lasercyber.lws.ui.common.utils.VideoUploadProgressDialog;

/**
 * Java bridge for DevActivity Kotlin — Lombok chain setters are not visible to Kotlin.
 */
final class DevActivitySupport {

    private DevActivitySupport() {
    }

    static void setRecordingListener(EasyPlayerClientManger.IPlayerClientListener listener) {
        EasyPlayerClientManger.getInstance().setListener(listener);
    }

    static void configureProcessType(ProcessParametersData data, int processType) {
        data.setProcessType(processType);
    }

    static void startVideoUpload(
            Activity activity,
            String localFilePath,
            ProcessParametersData processParametersData,
            Handler handler,
            VideoUploadProgressDialog dialog,
            Runnable onDismissDialog,
            java.util.function.BooleanSupplier isCancelledByUser) {
        SubmitProcessDataAndVideo submit = new SubmitProcessDataAndVideo()
                .setVideoPath(localFilePath)
                .setProcessParametersData(processParametersData)
                .setOssAsyncResumableUploadSuccess((request, result, type) -> {
                    if (type == UploadFileType.VIDEO) {
                        handler.post(onDismissDialog);
                        ToastUtils.showShort(R.string.upload_successful);
                    }
                })
                .setOssAsyncResumableUploadFail((request, clientException, serviceException, type) -> {
                    handler.post(() -> {
                        onDismissDialog.run();
                        if (isCancelledByUser.getAsBoolean()) {
                            ToastUtils.showShort(R.string.upload_cancelled);
                            return;
                        }
                        ToastUtils.showShort(R.string.upload_failed);
                    });
                })
                .setOssProgressCallback((request, currentSize, totalSize, type) -> {
                    if (type != UploadFileType.VIDEO || totalSize <= 0 || dialog == null) {
                        return;
                    }
                    int progress = (int) Math.min(100L, (currentSize * 100L) / totalSize);
                    String phase = activity.getString(R.string.video_upload_phase_video);
                    handler.post(() -> dialog.updateProgress(progress, phase + " · " + progress + "%"));
                });
        VideoAndProcessParamsHandler.saveVideoAndProcessParams(submit);
    }
}
