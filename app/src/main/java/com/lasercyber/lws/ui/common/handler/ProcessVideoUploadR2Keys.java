package com.lasercyber.lws.ui.common.handler;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;

/**
 * 工艺视频 R2 对象 key（{@code uploads/devices/{sn}/videos/{yyyy-MM-dd}/…}）：
 * Monitor 列表上传与 {@linkplain VideoAndProcessParamsHandler 录制完成后的首次上传} 共用。
 */
public final class ProcessVideoUploadR2Keys {
    private ProcessVideoUploadR2Keys() {
    }

    @NonNull
    public static String videoObjectKey(@NonNull String snTrimmed, @NonNull String yyyyMmDd,
            @NonNull String videoIdUuid, @NonNull String extLowerNoDot) {
        String sn = snTrimmed.trim();
        String ext = extLowerNoDot.startsWith(".") ? extLowerNoDot.substring(1) : extLowerNoDot;
        return "uploads/devices/" + sn + "/videos/" + yyyyMmDd + "/" + videoIdUuid.trim() + "." + ext;
    }

    /**
     * Path segment {@code yyyy-MM-dd} from a wall-clock instant in the <b>system default</b> time zone.
     * Intended for {@link com.lasercyber.lws.ui.bean.entity.ProcessParamsVideo#getCreateTime()} (epoch ms).
     */
    @NonNull
    public static String yyyyMmDdFromCreateTimeMillis(@Nullable Long createTimeMillis) {
        long ms = (createTimeMillis != null && createTimeMillis > 0L)
                ? createTimeMillis
                : System.currentTimeMillis();
        return Instant.ofEpochMilli(ms)
                .atZone(ZoneId.systemDefault())
                .toLocalDate()
                .format(DateTimeFormatter.ISO_LOCAL_DATE);
    }

    /**
     * Same as {@link #yyyyMmDdFromCreateTimeMillis(Long)} for a raw epoch millis (e.g. {@link java.util.Date#getTime()},
     * {@link java.io.File#lastModified()}).
     */
    @NonNull
    public static String yyyyMmDdFromEpochMillis(long epochMillis) {
        return yyyyMmDdFromCreateTimeMillis(epochMillis > 0L ? epochMillis : null);
    }

    @NonNull
    public static String videoExtFromPath(@NonNull String localPath) {
        int i = localPath.lastIndexOf('.');
        if (i < 0 || i >= localPath.length() - 1) {
            return "mp4";
        }
        String ext = localPath.substring(i + 1).trim().toLowerCase();
        if (ext.isEmpty() || ext.length() > 8) {
            return "mp4";
        }
        return ext;
    }
}
