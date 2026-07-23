package com.lasercyber.lws.ui.common.ai.video;

import android.content.Context;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.bean.entity.vo.ProcessParamsVideoVo;

import java.io.File;
import java.util.HashMap;
import java.util.Map;

/**
 * Process-wide registry of active {@link ProcessVideoAiSession} instances keyed by inference cache key.
 */
public final class ProcessVideoAiSessionRegistry {

    public enum Holder {
        UI,
        HTTP
    }

    private static final ProcessVideoAiSessionRegistry INSTANCE = new ProcessVideoAiSessionRegistry();

    private final Object lock = new Object();
    private final Map<String, ProcessVideoAiSession> sessions = new HashMap<>();

    private ProcessVideoAiSessionRegistry() {
    }

    @NonNull
    public static ProcessVideoAiSessionRegistry getInstance() {
        return INSTANCE;
    }

    public static final class AcquireResult {
        @Nullable
        public final ProcessVideoAiSession session;
        @NonNull
        public final ProcessVideoAiSession.CreateFailure failure;

        AcquireResult(@Nullable ProcessVideoAiSession session,
                      @NonNull ProcessVideoAiSession.CreateFailure failure) {
            this.session = session;
            this.failure = failure;
        }

        public boolean isSuccess() {
            return session != null;
        }
    }

    @NonNull
    public AcquireResult acquireResult(@NonNull Context context,
                                       @NonNull ProcessParamsVideoVo processVideo,
                                       @NonNull File sourceFile,
                                       boolean force,
                                       @NonNull Holder holder) {
        String cacheKey = ProcessVideoAiInferencePaths.cacheKey(processVideo, sourceFile);
        synchronized (lock) {
            ProcessVideoAiSession existing = sessions.get(cacheKey);
            if (force && existing != null) {
                existing.stop(true);
                sessions.remove(cacheKey);
                existing = null;
            }
            if (existing == null) {
                ProcessVideoAiSession.CreateResult createResult = ProcessVideoAiSession.tryCreate(
                        context.getApplicationContext(),
                        processVideo,
                        sourceFile,
                        cacheKey);
                if (!createResult.isSuccess()) {
                    return new AcquireResult(null, createResult.getFailure());
                }
                ProcessVideoAiSession created = createResult.getSession();
                if (!created.start()) {
                    created.stop(true);
                    return new AcquireResult(null, ProcessVideoAiSession.CreateFailure.ENGINE_NOT_RUNNING);
                }
                sessions.put(cacheKey, created);
                existing = created;
            }
            existing.addRef(holder);
            return new AcquireResult(existing, ProcessVideoAiSession.CreateFailure.NONE);
        }
    }

    /**
     * @return null when {@link #acquireResult} reports a failure.
     */
    @Nullable
    public ProcessVideoAiSession acquire(@NonNull Context context,
                                         @NonNull ProcessParamsVideoVo processVideo,
                                         @NonNull File sourceFile,
                                         boolean force,
                                         @NonNull Holder holder) {
        return acquireResult(context, processVideo, sourceFile, force, holder).session;
    }

    public void release(@NonNull ProcessVideoAiSession session, @NonNull Holder holder) {
        synchronized (lock) {
            if (session.releaseRef(holder) <= 0) {
                sessions.remove(session.getCacheKey());
                session.stop(false);
            }
        }
    }

    /** Test-only. */
    public void resetForTest() {
        synchronized (lock) {
            for (ProcessVideoAiSession session : sessions.values()) {
                session.stop(true);
            }
            sessions.clear();
        }
    }
}
