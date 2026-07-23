package com.lasercyber.lws.ui.activitys.device.monitor.model;

import android.content.Context;
import android.util.Log;

import androidx.lifecycle.LiveData;

import com.blankj.utilcode.util.GsonUtils;
import com.blankj.utilcode.util.StringUtils;
import com.blankj.utilcode.util.ToastUtils;
import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.engineer.mode.model.BaseProcessParametersDataViewModel;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.bean.entity.ProcessParamsVideo;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.utils.convert.EngineerWashConvert;

import java.io.File;
import java.util.function.Consumer;

import lombok.Getter;

public class ProcessVideoDetailsViewModel extends BaseProcessParametersDataViewModel {
    private static final String TAG = LogTAGConstant.ProcessVideoDetailsViewModel;
    @Getter
    private LiveData<ProcessParamsVideo> processParamsVideo;

    public void init(Context context, long processVideoId) {
        AppDatabase appDataBase = AppDatabase.getInstance(context);
        processParamsVideo = appDataBase.processProcessVideoDao().selectLiveDataById(processVideoId);
        parameterSettingsLiveData = appDataBase.advancedSettingsDao().selectOneLiveData();
        commonSettingsLiveData = appDataBase.commonSettingsDao().selectOneLiveData();
        initUseMMUnitLiveData();
    }

    public ProcessParamsVideo getProcessParamsVideoProxy() {
        if (processParamsVideo == null) {
            return null;
        }
        return processParamsVideo.getValue();
    }

    @Override
    public ProcessParametersData getDataProxy() {
        ProcessParamsVideo value = getProcessParamsVideoProxy();
        if (value == null) {
            return null;
        }
        String raw = value.getProcessParametersJson();
        if (StringUtils.isEmpty(raw) || raw.trim().isEmpty()) {
            return null;
        }
        try {
            return GsonUtils.fromJson(raw.trim(), ProcessParametersData.class);
        } catch (Exception e) {
            Log.w(TAG, "getDataProxy: skip invalid processParametersJson", e);
            return null;
        }
    }

    /**
     * 无工艺 JSON 时，用视频行上的 {@link ProcessParamsVideo#getMaterialType()} 作为展示回退。
     */
    @Override
    public String getMaterialTypeLabel() {
        ProcessParametersData data = getDataProxy();
        if (data != null) {
            return super.getMaterialTypeLabel();
        }
        ProcessParamsVideo row = getProcessParamsVideoProxy();
        if (row == null || row.getMaterialType() == null) {
            return "";
        }
        String text = EngineerWashConvert.convertCleaningMaterialsText(row.getMaterialType());
        return text != null ? text : "";
    }

    /**
     * 是否连续焊接
     */
    public boolean isContinuousWelding() {
        ProcessParamsVideo value = getProcessParamsVideoProxy();
        if (value == null || value.getProcessType() == null) {
            return false;
        }
        return value.getProcessType() == ModelConstant.CONTINUOUS_WELDING;
    }

    /**
     * 是否点焊
     */
    public boolean isPointWelding() {
        ProcessParamsVideo value = getProcessParamsVideoProxy();
        if (value == null || value.getProcessType() == null) {
            return false;
        }
        return value.getProcessType() == ModelConstant.POINT_WELDING;
    }

    /**
     * 是否焊道清洗
     */
    public boolean isWeldClean() {
        ProcessParamsVideo value = getProcessParamsVideoProxy();
        if (value == null || value.getProcessType() == null) {
            return false;
        }
        return value.getProcessType() == ModelConstant.WELD_CLEAN;
    }

    /**
     * 是否宽幅清洗
     */
    public boolean isWidthClean() {
        ProcessParamsVideo value = getProcessParamsVideoProxy();
        if (value == null || value.getProcessType() == null) {
            return false;
        }
        return value.getProcessType() == ModelConstant.WIDTH_CLEAN;
    }

    /**
     * 是否手动切割
     */
    public boolean isHandCut() {
        ProcessParamsVideo value = getProcessParamsVideoProxy();
        if (value == null || value.getProcessType() == null) {
            return false;
        }
        return value.getProcessType() == ModelConstant.HAND_CUT;
    }

    /**
     * 是否CNC切割
     */
    public boolean isCncCut() {
        ProcessParamsVideo value = getProcessParamsVideoProxy();
        if (value == null || value.getProcessType() == null) {
            return false;
        }
        return value.getProcessType() == ModelConstant.CNC_CUT;
    }

    /**
     * 获取模式名称
     *
     * @return
     */
    public String getModelName() {
        ProcessParamsVideo value = getProcessParamsVideoProxy();
        if (value == null || value.getProcessType() == null) {
            return "";
        }
        return ModelConstant.convertToText(value.getProcessType());
    }

    /**
     * 删除视频
     *
     * @param callBack
     */
    public void delete(Consumer<Integer> callBack) {
        LiveData<ProcessParamsVideo> paramsVideoLiveData = getProcessParamsVideo();
        if (paramsVideoLiveData == null) {
            ToastUtils.showShort(R.string.video_deletion_failed_text);
            return;
        }
        ProcessParamsVideo processParamsVideo = paramsVideoLiveData.getValue();
        if (processParamsVideo == null) {
            ToastUtils.showShort(R.string.video_deletion_failed_text);
            return;
        }
        // 删除视频文件
        if (processParamsVideo.getVideoPath() != null) {
            Log.d(TAG, "delete: " + processParamsVideo.getVideoPath());
            File file = new File(processParamsVideo.getVideoPath());
            if (file.exists()) {
                boolean delete = file.delete();
                if (delete) {
                    Log.d(TAG, "文件删除成功");
                } else {
                    Log.d(TAG, "文件删除失败");
                    Log.w(TAG, "delete: continue to remove db row even though file unlink failed");
                }
            }
        }
        ThreadPoolManager.getExecutor().execute(() -> {
            int deleted = AppDatabase.getInstance(Utils.getApp()).processProcessVideoDao().deleteById(processParamsVideo.getId());
            Log.d(TAG, "delete: 删除视频结果:" + deleted);
            callBack.accept(deleted);
            ToastUtils.showShort(R.string.video_deleted_successfully_text);
        });

    }
}
