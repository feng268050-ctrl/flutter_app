package com.lasercyber.lws.ui.bean.event;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.bean.entity.WarnTable;

import java.util.Collections;
import java.util.List;

/**
 * Posted when warning logs are inserted or cleared and visible lists should refresh.
 */
public final class WarnLogChangedEvent {

    public enum Kind {
        CLEARED,
        INSERTED,
        /** HMI list refresh only; no LAN SSE emission. */
        REFRESH
    }

    private final Kind kind;
    @Nullable
    private final List<WarnTable> insertedRows;

    private WarnLogChangedEvent(@NonNull Kind kind, @Nullable List<WarnTable> insertedRows) {
        this.kind = kind;
        this.insertedRows = insertedRows;
    }

    @NonNull
    public static WarnLogChangedEvent cleared() {
        return new WarnLogChangedEvent(Kind.CLEARED, null);
    }

    @NonNull
    public static WarnLogChangedEvent inserted(@NonNull List<WarnTable> rows) {
        return new WarnLogChangedEvent(Kind.INSERTED, rows);
    }

    @NonNull
    public static WarnLogChangedEvent inserted(@NonNull WarnTable row) {
        return inserted(Collections.singletonList(row));
    }

    @NonNull
    public static WarnLogChangedEvent refresh() {
        return new WarnLogChangedEvent(Kind.REFRESH, null);
    }

    @NonNull
    public Kind getKind() {
        return kind;
    }

    @Nullable
    public List<WarnTable> getInsertedRows() {
        return insertedRows;
    }
}
