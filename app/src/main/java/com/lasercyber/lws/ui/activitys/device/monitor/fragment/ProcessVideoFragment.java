package com.lasercyber.lws.ui.activitys.device.monitor.fragment;

import android.app.Activity;
import android.content.Intent;
import android.util.Log;

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.lifecycle.ViewModelProvider;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.blankj.utilcode.util.ToastUtils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.BaseFragment;
import com.lasercyber.lws.ui.activitys.device.monitor.model.ProcessVideoViewModel;
import com.lasercyber.lws.ui.activitys.video.details.ProcessVideoDetailsActivity;
import com.lasercyber.lws.ui.bean.entity.PageData;
import com.lasercyber.lws.ui.bean.entity.vo.ProcessParamsVideoVo;
import com.lasercyber.lws.ui.common.constant.IntentParamsConstants;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.handler.MonitorProcessVideoListUploadRunner;
import com.lasercyber.lws.ui.common.utils.VideoUploadProgressDialog;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.component.adapter.ProcessVideoListAdapter;
import com.lasercyber.lws.ui.databinding.FragmentProcessVideoBinding;
import com.scwang.smart.refresh.layout.api.RefreshLayout;

import java.util.Objects;
import java.util.concurrent.atomic.AtomicReference;
import java.util.function.Consumer;

/**
 * A simple {@link Fragment} subclass.
 * Use the {@link ProcessVideoFragment#newInstance} factory method to
 * create an instance of this fragment.
 * 视频列表页面
 */
public class ProcessVideoFragment extends BaseFragment<FragmentProcessVideoBinding> {
    private static final String TAG = LogTAGConstant.ProcessVideoFragment;
    /** Resumed Videos list instance, for WebSocket {@code command.upload_video} to reuse the same dialog as manual upload. */
    private static final AtomicReference<ProcessVideoFragment> activeListFragment = new AtomicReference<>();
    private ProcessVideoViewModel processVideoViewModel;
    private ProcessVideoListAdapter processVideoListAdapter;
    private LinearLayoutManager linearLayoutManager;
    @Nullable
    private VideoUploadProgressDialog videoUploadProgressDialog;
    private volatile boolean uploadCancelledByUser;
    private int latestTotal;
    private boolean loadMoreInFlight;
    private int paginationGeneration;
    private boolean footerLoading;
    @Nullable
    private String footerDisplayText;
    // 注册Activity结果回调
    private ActivityResultLauncher<Intent> deleteResultLauncher;

    @Override
    protected int getLayoutId() {
        return R.layout.fragment_process_video;
    }

    @Override
    protected void initView() {
        initResultLauncher();
        processVideoViewModel = new ViewModelProvider(this).get(ProcessVideoViewModel.class);
        processVideoListAdapter = new ProcessVideoListAdapter(getContext());
        updateFooter(false);
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
                Log.d(TAG, "detailsData: 进入详情页面:" + processParamsVideo);
                handler.post(() -> {
                    Intent intent = new Intent(requireContext(), ProcessVideoDetailsActivity.class);
                    intent.putExtra(IntentParamsConstants.PROCESS_DATA_VIDEO_ID, processParamsVideo.getId());
                    deleteResultLauncher.launch(intent);
                });
            }
        });
        linearLayoutManager = new LinearLayoutManager(getContext());
        linearLayoutManager.setOrientation(LinearLayoutManager.VERTICAL);
        binding.videoList.setAdapter(processVideoListAdapter);
        binding.videoList.setLayoutManager(linearLayoutManager);
        binding.videoList.addOnScrollListener(new RecyclerView.OnScrollListener() {
            @Override
            public void onScrolled(@NonNull RecyclerView recyclerView, int dx, int dy) {
                super.onScrolled(recyclerView, dx, dy);
                if (dy <= 0) {
                    return;
                }
                int itemCount = processVideoListAdapter.getItemCount();
                if (itemCount <= 0) {
                    return;
                }
                int lastVisible = linearLayoutManager.findLastVisibleItemPosition();
                if (lastVisible >= itemCount - 1) {
                    requestLoadMore();
                }
            }
        });
        binding.refreshVideoLayout.setEnableLoadMore(false);
        binding.refreshVideoLayout.setOnRefreshListener(refreshLayout -> {
            Log.d(TAG, "onRefresh: 刷新");
            refreshData(refreshLayout);
        });
    }

    /**
     * 刷新数据
     */
    private void refreshData(@Nullable RefreshLayout refreshLayout) {
        loadMoreInFlight = false;
        int generation = ++paginationGeneration;
        processVideoViewModel.resetSearch(processParamsVideoPageData -> {
            Log.d(TAG, "accept: 刷新数据:" + processParamsVideoPageData);
            handler.post(() -> updateRefresh(processParamsVideoPageData, generation, refreshLayout));
        });
    }

    private void updateRefresh(PageData<ProcessParamsVideoVo> pageData, int generation, @Nullable RefreshLayout refreshLayout) {
        if (generation != paginationGeneration) {
            return;
        }
        if (refreshLayout != null) {
            refreshLayout.finishRefresh(pageData != null);
        }
        if (pageData == null) {
            updateFooter(false);
            return;
        }
        latestTotal = pageData.getTotal();
        boolean explicitRefresh = refreshLayout != null;
        processVideoListAdapter.resetData(pageData.getList());
        if (explicitRefresh && linearLayoutManager != null) {
            linearLayoutManager.scrollToPositionWithOffset(0, 0);
        }
        updateFooter(false);
    }

    /**
     * 更新加载更多
     */
    private void updateLoadMore(PageData<ProcessParamsVideoVo> processParamsVideoPageData, int generation) {
        if (generation != paginationGeneration) {
            return;
        }
        loadMoreInFlight = false;
        if (processParamsVideoPageData == null) {
            updateFooter(false);
            return;
        }
        latestTotal = processParamsVideoPageData.getTotal();
        processVideoListAdapter.pushData(processParamsVideoPageData.getList());
        updateFooter(false);
        if (processParamsVideoPageData.getDataSize() > 0 && hasMoreData()) {
            Log.d(TAG, "updateLoadMore: page appended, more data remains");
        } else {
            Log.d(TAG, "updateLoadMore: no more data");
        }
    }

    private void requestLoadMore() {
        if (!hasMoreData()) {
            return;
        }
        if (loadMoreInFlight) {
            return;
        }
        loadMoreInFlight = true;
        int generation = paginationGeneration;
        updateFooter(true);
        processVideoViewModel.listMore(processParamsVideoPageData -> {
            Log.d(TAG, "加载更多数据:" + processParamsVideoPageData);
            handler.post(() -> updateLoadMore(processParamsVideoPageData, generation));
        });
    }

    private boolean hasMoreData() {
        return processVideoListAdapter.getDataCount() < latestTotal;
    }

    private void updateFooter(boolean loading) {
        if (binding == null) {
            return;
        }
        String displayText = loading
                ? getString(R.string.loading_text)
                : getString(
                        R.string.process_video_loaded_total_format,
                        processVideoListAdapter.getDataCount(),
                        latestTotal);
        if (loading == footerLoading && Objects.equals(displayText, footerDisplayText)) {
            return;
        }
        footerLoading = loading;
        footerDisplayText = displayText;
        binding.videoListFooterText.setText(displayText);
    }

    @Override
    protected void initData() {
        processVideoViewModel.init(getContext());
        int generation = ++paginationGeneration;
        processVideoViewModel.resetSearch(processParamsVideoPageData -> {
            Log.d(TAG, "分页加载的数据:" + processParamsVideoPageData);
            handler.post(() -> updateRefresh(processParamsVideoPageData, generation, null));
        });
    }

    /**
     * 上传视频（元数据 + STS）；数据从数据库行 {@code rowId} 读取。
     */
    private void doUploadVideo(long rowId) {
        uploadCancelledByUser = false;
        dismissVideoUploadProgress();
        videoUploadProgressDialog = new VideoUploadProgressDialog(requireActivity(), () -> {
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
                    if (!isAdded() || videoUploadProgressDialog == null) {
                        return;
                    }
                    videoUploadProgressDialog.updateProgress(0, getString(R.string.video_upload_phase_metadata));
                });
            }

            @Override
            public void onVideoProgress(int percent0to100, @Nullable String detail) {
                handler.post(() -> {
                    if (!isAdded() || videoUploadProgressDialog == null) {
                        return;
                    }
                    String phase = getString(R.string.video_upload_phase_video);
                    videoUploadProgressDialog.updateProgress(percent0to100, phase + " · " + percent0to100 + "%");
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

    /**
     * If the monitor Videos list is resumed, starts the same upload UI as a manual tap. Must run on the main thread.
     *
     * @return {@code true} if this fragment handled the upload
     */
    public static boolean tryStartUploadFromWebSocketCommand(long rowId) {
        ProcessVideoFragment f = activeListFragment.get();
        if (f == null || !f.isAdded() || !f.isResumed() || f.getActivity() == null) {
            return false;
        }
        f.doUploadVideo(rowId);
        return true;
    }

    @Override
    public void onResume() {
        super.onResume();
        activeListFragment.set(this);
    }

    @Override
    public void onPause() {
        activeListFragment.compareAndSet(this, null);
        super.onPause();
    }

    @Override
    public void onDestroyView() {
        activeListFragment.compareAndSet(this, null);
        dismissVideoUploadProgress();
        linearLayoutManager = null;
        super.onDestroyView();
    }

    @Override
    public long fragmentId() {
        return 10000;
    }

    private void initResultLauncher() {
        deleteResultLauncher = registerForActivityResult(
                new ActivityResultContracts.StartActivityForResult(),
                result -> {
                    if (result.getResultCode() == Activity.RESULT_OK && result.getData() != null) {
                        boolean isDeleted = result.getData().getBooleanExtra(IntentParamsConstants.DELETE_DATA_SUCCESS, false);
                        Log.d(TAG, "删除结果:" + isDeleted);
                        if (binding == null) {
                            return;
                        }
                        if (isDeleted) {
                            refreshData(binding.refreshVideoLayout);
                        }
                    }
                }
        );
    }
}
