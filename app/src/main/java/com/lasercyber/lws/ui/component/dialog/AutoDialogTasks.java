package com.lasercyber.lws.ui.component.dialog;

import android.app.Activity;
import android.content.ComponentName;
import android.content.Context;
import android.graphics.Bitmap;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.blankj.utilcode.util.ActivityUtils;
import com.blankj.utilcode.util.StringUtils;
import com.lasercyber.lws.ui.bean.entity.vo.WarnDialogVo;
import com.lasercyber.lws.ui.component.dialog.episode.WarnEpisodeController;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.queue.EnqueuePolicy;
import com.lasercyber.lws.ui.common.queue.SerialTaskQueue;

import java.lang.ref.WeakReference;

final class WarnAutoDialogTask implements AutoDialogTask {

    private final WeakReference<Context> contextRef;
    private final WarnDialogVo vo;
    private final boolean consumeReminder;
    private final int priority;

    private WarnAutoDialogTask(
            @NonNull Context context,
            @NonNull WarnDialogVo vo,
            boolean consumeReminder,
            int priority) {
        this.contextRef = new WeakReference<>(context);
        this.vo = vo;
        this.consumeReminder = consumeReminder;
        this.priority = priority;
    }

    static WarnAutoDialogTask passive(@NonNull Context context, @NonNull WarnDialogVo vo) {
        return new WarnAutoDialogTask(context, vo, true, PRIORITY_PASSIVE_ALARM);
    }

    static WarnAutoDialogTask immediate(@NonNull Context context, @NonNull WarnDialogVo vo) {
        return new WarnAutoDialogTask(context, vo, false, PRIORITY_IMMEDIATE_ALARM);
    }

    @NonNull
    static String taskId(@Nullable String errorCode) {
        return "warn:" + (StringUtils.isEmpty(errorCode) ? "generic" : errorCode);
    }

    @Override
    @NonNull
    public String id() {
        return taskId(vo.getErrorCode());
    }

    @Override
    public int priority() {
        return priority;
    }

    @Override
    public boolean isReady() {
        if (WarnDialogUtil.isDialogShowing()
                && !WarnDialogUtil.isShowingErrorCode(vo.getErrorCode())) {
            return false;
        }
        Activity activity = resolveActivity();
        if (activity == null || activity.isFinishing() || activity.isDestroyed()) {
            return false;
        }
        ComponentName componentName = activity.getComponentName();
        return componentName == null
                || !".activitys.SafetyTipsActivity".equals(componentName.getShortClassName());
    }

    @Override
    public boolean run(@NonNull Runnable onComplete) {
        Activity activity = resolveActivity();
        if (activity == null) {
            return false;
        }
        if (consumeReminder && !StringUtils.isEmpty(vo.getErrorCode())) {
            if (!WarnEpisodeController.tryConsumeReminderForDialog(vo.getErrorCode())) {
                return false;
            }
        }
        if (consumeReminder && !StringUtils.isEmpty(vo.getErrorCode())
                && !WarnEpisodeController.isFaultActive(vo.getErrorCode())) {
            return false;
        }
        boolean shown = WarnDialogUtil.openDialog(activity, vo, dialog -> onComplete.run(), dialog -> {
            if (consumeReminder && !StringUtils.isEmpty(vo.getErrorCode())) {
                WarnEpisodeController.markDialogOpen(vo.getErrorCode());
            }
        });
        return shown;
    }

    @Nullable
    private Activity resolveActivity() {
        Context context = contextRef.get();
        if (context instanceof Activity activity
                && !activity.isFinishing()
                && !activity.isDestroyed()) {
            return activity;
        }
        Activity top = ActivityUtils.getTopActivity();
        if (top != null && !top.isFinishing() && !top.isDestroyed()) {
            return top;
        }
        return null;
    }
}

final class FrostAutoDialogTask implements AutoDialogTask {

    private final String taskId;
    private final int priority;
    private final AutoDialogQueue.FrostDialogPresenter presenter;

    FrostAutoDialogTask(
            @NonNull String taskId,
            int priority,
            @NonNull AutoDialogQueue.FrostDialogPresenter presenter) {
        this.taskId = taskId;
        this.priority = priority;
        this.presenter = presenter;
    }

    @Override
    @NonNull
    public String id() {
        return taskId;
    }

    @Override
    public int priority() {
        return priority;
    }

    @Override
    public boolean isReady() {
        return !WarnDialogUtil.isDialogShowing();
    }

    @Override
    public boolean run(@NonNull Runnable onComplete) {
        return presenter.show(onComplete);
    }
}
