package com.lasercyber.lws.ui.bean.event;

import androidx.annotation.Nullable;

public class RemoteUpdateUiEvent {
    public enum Type {
        UPDATE_SYSTEM_TRIGGERED,
        UPDATE_SYSTEM_REJECTED
    }

    private final Type type;
    @Nullable
    private final String message;
    @Nullable
    private final String version;
    private final boolean hasUpdate;
    private final boolean ok;

    private RemoteUpdateUiEvent(Type type, @Nullable String message, @Nullable String version, boolean hasUpdate, boolean ok) {
        this.type = type;
        this.message = message;
        this.version = version;
        this.hasUpdate = hasUpdate;
        this.ok = ok;
    }

    public static RemoteUpdateUiEvent updateTriggered(@Nullable String version) {
        return new RemoteUpdateUiEvent(Type.UPDATE_SYSTEM_TRIGGERED, null, version, false, true);
    }

    public static RemoteUpdateUiEvent updateRejected(@Nullable String message) {
        return new RemoteUpdateUiEvent(Type.UPDATE_SYSTEM_REJECTED, message, null, false, false);
    }

    public Type getType() {
        return type;
    }

    @Nullable
    public String getMessage() {
        return message;
    }

    @Nullable
    public String getVersion() {
        return version;
    }

    public boolean hasUpdate() {
        return hasUpdate;
    }

    public boolean isOk() {
        return ok;
    }
}
