package com.lasercyber.lws.ui.activitys.device.monitor.model;


import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.lifecycle.ViewModel;

import com.blankj.utilcode.util.ToastUtils;
import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.bean.entity.PageData;
import com.lasercyber.lws.ui.bean.entity.ProcessParamsVideo;
import com.lasercyber.lws.ui.bean.entity.vo.ProcessParamsVideoVo;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.handler.MonitorListForegroundUploadCoordinator;
import com.lasercyber.lws.ui.common.handler.MonitorProcessVideoListUploadRunner;
import com.lasercyber.lws.ui.common.handler.ProcessVideoDeleteHelper;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.repository.ProcessProcessVideoDao;

import java.util.List;
import java.util.function.Consumer;


public class ProcessVideoViewModel extends ViewModel {
    private static final String TAG = LogTAGConstant.ProcessVideoViewModel;
    private final int pageSize = 10;
    private int pageNum = 1;
    private ProcessProcessVideoDao processProcessVideoDao;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    public void init(Context context) {
        AppDatabase appDataBase = AppDatabase.getInstance(context);
        processProcessVideoDao = appDataBase.processProcessVideoDao();
    }

    /**
     * 重置检索
     *
     * @param consumer
     */
    public void resetSearch(Consumer<PageData<ProcessParamsVideoVo>> consumer) {
        pageNum = 1;
        listMore(consumer);
    }

    /**
     * 加载更多
     *
     * @param consumer
     */
    public void listMore(Consumer<PageData<ProcessParamsVideoVo>> consumer) {
        ThreadPoolManager.getExecutor().execute(() -> {
            int requestPage = pageNum;
            List<ProcessParamsVideoVo> list = processProcessVideoDao.selectPage(requestPage, pageSize);
            long totalRows = processProcessVideoDao.countAllProcessVideos();
            int total = totalRows > Integer.MAX_VALUE ? Integer.MAX_VALUE : (int) totalRows;
            PageData<ProcessParamsVideoVo> pageData = new PageData<>();
            pageData.setList(list)
                    .setPageSize(pageSize)
                    .setPageNum(requestPage)
                    .setTotal(total);
            consumer.accept(pageData);
            if (list != null && !list.isEmpty() && requestPage * pageSize < total) {
                pageNum = requestPage + 1;
            }
        });
    }

    /**
     * 删除视频
     *
     * @param processParamsVideo
     * @param callBack
     */
    public void delete(ProcessParamsVideoVo processParamsVideo, Consumer<Integer> callBack) {
        ThreadPoolManager.getExecutor().execute(() -> {
            ProcessVideoDeleteHelper.Outcome outcome = ProcessVideoDeleteHelper.deleteByLocalRowId(
                    Utils.getApp(), processParamsVideo.getId());
            int deleted = outcome == ProcessVideoDeleteHelper.Outcome.SUCCESS ? 1 : 0;
            Log.d(TAG, "delete: outcome=" + outcome + " rows=" + deleted);
            mainHandler.post(() -> {
                if (outcome == ProcessVideoDeleteHelper.Outcome.FILE_DELETE_FAILED) {
                    ToastUtils.showShort(R.string.video_deletion_failed_text);
                    callBack.accept(0);
                    return;
                }
                if (deleted > 0) {
                    ToastUtils.showShort(R.string.video_deleted_successfully_text);
                }
                callBack.accept(deleted);
            });
        });
    }

    /**
     * 加载单条数据
     *
     * @param processParamsVideoVo
     * @param callBack
     */
    public void selectById(ProcessParamsVideoVo processParamsVideoVo, Consumer<ProcessParamsVideo> callBack) {
        ThreadPoolManager.getExecutor().execute(() -> {
            ProcessParamsVideo processParamsVideo = processProcessVideoDao.selectById(processParamsVideoVo.getId());
            callBack.accept(processParamsVideo);
        });
    }

    public void selectById(long rowId, Consumer<ProcessParamsVideo> callBack) {
        ThreadPoolManager.getExecutor().execute(() -> {
            ProcessParamsVideo processParamsVideo = processProcessVideoDao.selectById(rowId);
            callBack.accept(processParamsVideo);
        });
    }

    /**
     * Cancels the in-flight Monitor → Videos list foreground upload (STS path), if any.
     */
    public void cancelMonitorListForegroundUpload() {
        MonitorListForegroundUploadCoordinator.get().cancel();
    }

    /**
     * Starts metadata (when needed) then STS video upload for one DB row; callbacks run on {@code mainHandler}.
     */
    public void startMonitorListForegroundUpload(long rowId, MonitorProcessVideoListUploadRunner.Listener listener) {
        MonitorListForegroundUploadCoordinator.get().start(Utils.getApp(), rowId, mainHandler, listener);
    }

    @Override
    protected void onCleared() {
        cancelMonitorListForegroundUpload();
        super.onCleared();
    }
}
