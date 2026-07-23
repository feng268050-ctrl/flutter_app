package com.lasercyber.lws.ui.common.handler;

import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.bean.entity.ProcessParamsVideo;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.repository.ProcessProcessVideoDao;

import java.io.File;

/**
 * Shared delete path for process videos (local HTTP, WebSocket, UI).
 */
public final class ProcessVideoDeleteHelper {
    private static final String TAG = LogTAGConstant.ProcessVideoViewModel;

    public enum Outcome {
        SUCCESS,
        NOT_FOUND,
        FILE_DELETE_FAILED
    }

    private ProcessVideoDeleteHelper() {
    }

    /**
     * Delete by business {@link ProcessParamsVideo#getVideoId()} (UUID).
     */
    @NonNull
    public static Outcome deleteByVideoId(@NonNull Context context, @Nullable String videoId) {
        if (videoId == null || videoId.trim().isEmpty()) {
            return Outcome.NOT_FOUND;
        }
        ProcessProcessVideoDao dao = AppDatabase.getInstance(context).processProcessVideoDao();
        ProcessParamsVideo row = dao.selectByVideoId(videoId.trim());
        if (row == null) {
            return Outcome.NOT_FOUND;
        }
        return deleteRow(context, row);
    }

    /**
     * Delete by local Room row id (Monitor UI list).
     */
    @NonNull
    public static Outcome deleteByLocalRowId(@NonNull Context context, long localRowId) {
        ProcessProcessVideoDao dao = AppDatabase.getInstance(context).processProcessVideoDao();
        ProcessParamsVideo row = dao.selectById(localRowId);
        if (row == null) {
            return Outcome.NOT_FOUND;
        }
        return deleteRow(context, row);
    }

    @NonNull
    private static Outcome deleteRow(@NonNull Context context, @NonNull ProcessParamsVideo row) {
        String path = row.getVideoPath();
        if (path != null) {
            File file = new File(path);
            if (file.exists() && !file.delete()) {
                Log.d(TAG, "delete: file delete failed path=" + path);
                return Outcome.FILE_DELETE_FAILED;
            }
        }
        int deleted = AppDatabase.getInstance(context).processProcessVideoDao().deleteById(row.getId());
        Log.d(TAG, "delete: db rows=" + deleted + " videoId=" + row.getVideoId());
        return deleted > 0 ? Outcome.SUCCESS : Outcome.NOT_FOUND;
    }
}
