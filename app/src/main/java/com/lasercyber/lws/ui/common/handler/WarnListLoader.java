package com.lasercyber.lws.ui.common.handler;

import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.engineer.mode.model.WarnTableViewModel;
import com.lasercyber.lws.ui.bean.entity.WarnTable;
import com.lasercyber.lws.ui.bean.event.WarnLogChangedEvent;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.enums.AlarmCodeEnums;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.repository.WarnTableDao;

import org.greenrobot.eventbus.EventBus;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Loads and clears persisted warn rows with the same localization as
 * {@code command.stat_response} {@code payload.data.warns}.
 */
public final class WarnListLoader {

    private static final String TAG = "WarnListLoader";

    private WarnListLoader() {
    }

    /**
     * Room {@link com.lasercyber.lws.ui.repository.WarnTableDao#batchInsert} returns row ids but does
     * not mutate entities; apply before SSE / EventBus publish.
     */
    public static void applyInsertIds(@NonNull List<WarnTable> rows, @NonNull List<Long> insertIds) {
        int n = Math.min(rows.size(), insertIds.size());
        for (int i = 0; i < n; i++) {
            Long rowId = insertIds.get(i);
            if (rowId != null && rowId > 0L) {
                rows.get(i).setId(rowId);
            }
        }
    }

    @NonNull
    public static List<WarnTable> loadLocalizedWarnList(@NonNull Context context) {
        WarnTableViewModel warn = new WarnTableViewModel();
        List<WarnTable> warnList = warn.getWarnList(context);
        if (warnList == null || warnList.isEmpty()) {
            return Collections.emptyList();
        }
        List<WarnTable> out = new ArrayList<>(warnList.size());
        for (WarnTable row : warnList) {
            out.add(localizeRow(context, row));
        }
        return out;
    }

    @NonNull
    public static List<WarnTable> localizeRows(@NonNull Context context, @NonNull List<WarnTable> rows) {
        if (rows.isEmpty()) {
            return Collections.emptyList();
        }
        List<WarnTable> out = new ArrayList<>(rows.size());
        for (WarnTable row : rows) {
            out.add(localizeRow(context, row));
        }
        return out;
    }

    @NonNull
    public static WarnTable localizeRow(@NonNull Context context, @NonNull WarnTable row) {
        applyLocalizedContent(context, row);
        return row;
    }

    public static void applyLocalizedContent(@NonNull Context context, @NonNull WarnTable row) {
        int titleId = AlarmCodeEnums.findTitleId(row.getCode());
        if (titleId <= 0) {
            titleId = R.string.def_warn_text;
        }
        row.setContent(context.getString(titleId));
    }

    /**
     * Deletes all warn rows and notifies subscribers (SSE + HMI).
     */
    public static void clearAllWarns(@NonNull Context context) {
        Context app = context.getApplicationContext();
        ThreadPoolManager.getExecutor().execute(() -> performClearAll(app));
    }

    /**
     * Clears warns on the current thread; caller must not be the main thread.
     */
    public static void performClearAll(@NonNull Context appContext) {
        WarnTableDao warnTableDao = AppDatabase.getInstance(appContext).warnTableDao();
        warnTableDao.deleteAll();
        EventBus.getDefault().post(WarnLogChangedEvent.cleared());
    }

    public static void postInserted(@NonNull Context context, @Nullable List<WarnTable> rows) {
        if (rows == null || rows.isEmpty()) {
            return;
        }
        List<WarnTable> publishable = new ArrayList<>();
        for (WarnTable row : rows) {
            if (row.getId() == null) {
                Log.w(TAG, "skip INSERTED event for warn without id, code=" + row.getCode());
                continue;
            }
            publishable.add(row);
        }
        if (publishable.isEmpty()) {
            return;
        }
        EventBus.getDefault().post(
                WarnLogChangedEvent.inserted(localizeRows(context.getApplicationContext(), publishable)));
    }
}
