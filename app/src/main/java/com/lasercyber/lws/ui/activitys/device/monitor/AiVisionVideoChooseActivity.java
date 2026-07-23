package com.lasercyber.lws.ui.activitys.device.monitor;

import android.content.Intent;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.lifecycle.ViewModelProvider;
import androidx.recyclerview.widget.LinearLayoutManager;

import com.blankj.utilcode.util.ToastUtils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.BaseActivity;
import com.lasercyber.lws.ui.activitys.device.monitor.model.ProcessVideoViewModel;
import com.lasercyber.lws.ui.bean.entity.PageData;
import com.lasercyber.lws.ui.bean.entity.vo.ProcessParamsVideoVo;
import com.lasercyber.lws.ui.common.constant.IntentParamsConstants;
import com.lasercyber.lws.ui.common.handler.AiVisionInferenceUploadStateStore;
import com.lasercyber.lws.ui.common.handler.MonitorProcessVideoListUploadRunner;
import com.lasercyber.lws.ui.common.utils.VideoUploadProgressDialog;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.component.adapter.ProcessVideoListAdapter;
import com.lasercyber.lws.ui.databinding.ActivityAiVisionVideoChooseBinding;
import com.scwang.smart.refresh.layout.api.RefreshLayout;

import java.util.function.Consumer;

public class AiVisionVideoChooseActivity extends BaseActivity<ActivityAiVisionVideoChooseBinding> {
    private static final String TAG = "AiVisionVideoChooseActivity";
    private ProcessVideoViewModel processVideoViewModel;
    private ProcessVideoListAdapter processVideoListAdapter;
    @Nullable
    private VideoUploadProgressDialog videoUploadProgressDialog;
    private volatile boolean uploadCancelledByUser;

    @Override
    protected void initView() {
        processVideoViewModel = new ViewModelProvider(this).get(ProcessVideoViewModel.class);
        processVideoViewModel.init(this);
        processVideoListAdapter = new ProcessVideoListAdapter(this, true);
        processVideoListAdapter.setAiVisionUploadStateResolver(
                processVideo -> AiVisionInferenceUploadStateStore.isInferenceVideoUploaded(
                        this,
                        processVideo));
        processVideoListAdapter.setDataEventListener(new ProcessVideoListAdapter.DataEventListener() {
            @Override
            public void deleteData(ProcessParamsVideoVo processParamsVideo, int position, Consumer<Integer> callBack) {
                GlobalSoundManager.playClickSound();
                processVideoViewModel.delete(processParamsVideo, callBack);
            }

            @Override
            public void uploadData(ProcessParamsVideoVo processParamsVideo, int position) {
                GlobalSoundManager.playClickSound();
                Log.d(TAG, "uploadData: rowId=" + processParamsVideo.getId());
                handler.post(() -> doUploadVideo(processParamsVideo.getId()));
            }

            @Override
            public void detailsData(ProcessParamsVideoVo processParamsVideo, int position) {
                GlobalSoundManager.playClickSound();
                Intent result = new Intent();
                result.putExtra(IntentParamsConstants.AI_VISION_SELECTED_PROCESS_VIDEO, processParamsVideo);
                setResult(RESULT_OK, result);
                finish();
            }
        });

        LinearLayoutManager linearLayoutManager = new LinearLayoutManager(this);
        linearLayoutManager.setOrientation(LinearLayoutManager.VERTICAL);
        binding.videoList.setAdapter(processVideoListAdapter);
        binding.videoList.setLayoutManager(linearLayoutManager);
        binding.callBackPreviousPage.setOnClickListener(v -> {
            GlobalSoundManager.playClickSound();
            finish();
        });
        binding.refreshVideoLayout.setOnRefreshListener(this::refreshData);
        binding.refreshVideoLayout.setOnLoadMoreListener(refreshLayout -> processVideoViewModel.listMore(pageData ->
                handler.post(() -> updateLoadMore(refreshLayout, pageData))));
    }

    @Override
    protected void initData() {
        processVideoViewModel.resetSearch(pageData ->
                handler.post(() -> updateLoadMore(binding.refreshVideoLayout, pageData)));
    }

    @Override
    protected int getLayoutId() {
        return R.layout.activity_ai_vision_video_choose;
    }

    private void refreshData(RefreshLayout refreshLayout) {
        refreshLayout.setEnableLoadMore(true);
        processVideoViewModel.resetSearch(pageData -> handler.post(() -> {
            processVideoListAdapter.resetData(pageData.getList());
            refreshLayout.finishRefresh();
            refreshLayout.setNoMoreData(pageData.getDataSize() < pageData.getPageSize());
        }));
    }

    private void updateLoadMore(RefreshLayout refreshLayout, PageData<ProcessParamsVideoVo> pageData) {
        if (pageData == null) {
            refreshLayout.finishLoadMore();
            return;
        }
        processVideoListAdapter.pushData(pageData.getList());
        if (pageData.getDataSize() == pageData.getPageSize()) {
            refreshLayout.finishLoadMore();
        } else {
            refreshLayout.finishLoadMoreWithNoMoreData();
            refreshLayout.setEnableLoadMore(false);
        }
    }

    private void doUploadVideo(long rowId) {
        uploadCancelledByUser = false;
        dismissVideoUploadProgress();
        videoUploadProgressDialog = new VideoUploadProgressDialog(this, () -> {
            uploadCancelledByUser = true;
            processVideoViewModel.cancelMonitorListForegroundUpload();
            dismissVideoUploadProgress();
        });
        videoUploadProgressDialog.show();
        videoUploadProgressDialog.updateProgress(0, getString(R.string.uploading_in_progress));
        processVideoViewModel.startMonitorListForegroundUpload(rowId, new MonitorProcessVideoListUploadRunner.Listener() {
            @Override
            public void onMetadataPhaseStarted() {
                handler.post(() -> {
                    if (videoUploadProgressDialog != null) {
                        videoUploadProgressDialog.updateProgress(0, getString(R.string.video_upload_phase_metadata));
                    }
                });
            }

            @Override
            public void onVideoProgress(int percent0to100, @Nullable String detail) {
                handler.post(() -> {
                    if (videoUploadProgressDialog != null) {
                        String phase = getString(R.string.video_upload_phase_video);
                        videoUploadProgressDialog.updateProgress(percent0to100, phase + " · " + percent0to100 + "%");
                    }
                });
            }

            @Override
            public void onFinishedSuccess(@Nullable String videoPublicUrl) {
                handler.post(() -> {
                    dismissVideoUploadProgress();
                    ToastUtils.showShort(R.string.upload_successful);
                    processVideoListAdapter.markRowVideoCloudUploaded(rowId, videoPublicUrl);
                });
            }

            @Override
            public void onFinishedError(@Nullable String message) {
                handler.post(() -> {
                    dismissVideoUploadProgress();
                    if (uploadCancelledByUser || message == null) {
                        uploadCancelledByUser = false;
                        ToastUtils.showShort(R.string.upload_cancelled);
                        return;
                    }
                    Log.e(TAG, "upload finished with error: " + message);
                    String detail = message.length() > 100 ? message.substring(0, 100) + "…" : message;
                    ToastUtils.showShort(getString(R.string.upload_failed) + " · " + detail);
                });
            }
        });
    }

    private void dismissVideoUploadProgress() {
        if (videoUploadProgressDialog != null) {
            videoUploadProgressDialog.dismiss();
            videoUploadProgressDialog = null;
        }
    }

    @Override
    protected void onDestroy() {
        dismissVideoUploadProgress();
        if (processVideoViewModel != null) {
            processVideoViewModel.cancelMonitorListForegroundUpload();
        }
        super.onDestroy();
    }
}
