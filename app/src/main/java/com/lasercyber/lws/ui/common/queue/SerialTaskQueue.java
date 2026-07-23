package com.lasercyber.lws.ui.common.queue;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.Iterator;
import java.util.List;

/**
 * Main-thread serial task runner (event-loop style): one active task, FIFO within the same priority.
 */
public final class SerialTaskQueue {

    private static final String TAG = LogTAGConstant.SerialTaskQueue;

    private static final class Entry {
        private final SerialTask task;
        private final long sequence;

        private Entry(@NonNull SerialTask task, long sequence) {
            this.task = task;
            this.sequence = sequence;
        }
    }

    private static final long NOT_READY_RETRY_MS = 500L;

    private final Handler handler;
    @NonNull
    private final String name;
    private final List<Entry> pending = new ArrayList<>();
    private long nextSequence;
    private boolean drainPosted;
    private boolean prepareInFlight;
    @Nullable
    private SerialTask activeTask;

    public SerialTaskQueue(@NonNull String name) {
        this(name, Looper.getMainLooper());
    }

    public SerialTaskQueue(@NonNull String name, @NonNull Looper looper) {
        this.name = name;
        this.handler = new Handler(looper);
    }

    public void enqueue(@NonNull SerialTask task) {
        enqueue(task, EnqueuePolicy.SKIP_IF_PENDING);
    }

    public void enqueue(@NonNull SerialTask task, @NonNull EnqueuePolicy policy) {
        handler.post(() -> enqueueOnQueueThread(task, policy));
    }

    public void scheduleDrain() {
        handler.post(this::drainLoop);
    }

    public boolean isIdle() {
        return activeTask == null && pending.isEmpty() && !prepareInFlight;
    }

    public boolean isRunning(@NonNull String taskId) {
        return activeTask != null && taskId.equals(activeTask.id());
    }

    public void cancelPending(@NonNull String taskId) {
        handler.post(() -> pending.removeIf(entry -> taskId.equals(entry.task.id())));
    }

    public void clearPending() {
        handler.post(pending::clear);
    }

    /**
     * Drops the active task without running its completion callback (host destroyed / overlay torn down).
     */
    public void abandonActiveTask(@NonNull String reason) {
        handler.post(() -> {
            if (activeTask == null) {
                return;
            }
            Log.w(TAG, name + " abandon active " + activeTask.id() + ": " + reason);
            activeTask = null;
            scheduleDrainOnQueueThread();
        });
    }

    private void enqueueOnQueueThread(@NonNull SerialTask task, @NonNull EnqueuePolicy policy) {
        String taskId = task.id();
        if (policy == EnqueuePolicy.SKIP_IF_PENDING) {
            if (isPendingOrActive(taskId)) {
                return;
            }
        } else if (policy == EnqueuePolicy.REPLACE_PENDING) {
            pending.removeIf(entry -> taskId.equals(entry.task.id()));
            if (activeTask != null && taskId.equals(activeTask.id())) {
                Log.d(TAG, name + " skip replace active " + taskId);
                return;
            }
        }
        pending.add(new Entry(task, nextSequence++));
        sortPending();
        Log.d(TAG, name + " enqueue " + taskId + " priority=" + task.priority()
                + " pending=" + pending.size());
        scheduleDrainOnQueueThread();
    }

    private boolean isPendingOrActive(@NonNull String taskId) {
        if (activeTask != null && taskId.equals(activeTask.id())) {
            return true;
        }
        for (Entry entry : pending) {
            if (taskId.equals(entry.task.id())) {
                return true;
            }
        }
        return false;
    }

    private void sortPending() {
        pending.sort(Comparator
                .comparingInt((Entry entry) -> entry.task.priority())
                .thenComparingLong(entry -> entry.sequence));
    }

    private void scheduleDrainOnQueueThread() {
        if (drainPosted || prepareInFlight || activeTask != null) {
            return;
        }
        drainPosted = true;
        handler.post(() -> {
            drainPosted = false;
            drainLoop();
        });
    }

    private void drainLoop() {
        if (prepareInFlight || activeTask != null) {
            return;
        }
        boolean sawNotReady = false;
        Iterator<Entry> iterator = pending.iterator();
        while (iterator.hasNext()) {
            Entry entry = iterator.next();
            SerialTask task = entry.task;
            if (!task.isReady()) {
                sawNotReady = true;
                continue;
            }
            iterator.remove();
            prepareInFlight = true;
            task.prepare(() -> {
                prepareInFlight = false;
                if (!task.isReady()) {
                    pending.add(new Entry(task, nextSequence++));
                    sortPending();
                    scheduleDrainOnQueueThread();
                    return;
                }
                boolean started = task.run(() -> completeActive(task));
                if (started) {
                    activeTask = task;
                    Log.d(TAG, name + " running " + task.id());
                } else {
                    Log.d(TAG, name + " skipped " + task.id());
                    scheduleDrainOnQueueThread();
                }
            });
            return;
        }
        if (sawNotReady && !pending.isEmpty()) {
            handler.postDelayed(this::drainLoop, NOT_READY_RETRY_MS);
        }
    }

    private void completeActive(@NonNull SerialTask task) {
        if (activeTask != task) {
            return;
        }
        activeTask = null;
        Log.d(TAG, name + " finished " + task.id());
        scheduleDrainOnQueueThread();
    }
}
