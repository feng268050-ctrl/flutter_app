package com.lasercyber.lws.ui.component.dialog.episode;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.lasercyber.lws.ui.bean.entity.WarnMark;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.enums.AlarmCodeEnums;

/**
 * Low-level {@link WarnMark} read/write for {@link WarnEpisodeController}.
 * No business rules — persistence mirror only.
 */
final class WarnEpisodePersistence {

    private WarnEpisodePersistence() {
    }

    @Nullable
    static WarnMark read(@NonNull String warnCode) {
        return MemoryCacheManager.getInstance().getSerializable(cacheKey(warnCode));
    }

    static void write(@NonNull String warnCode, @NonNull WarnMark mark) {
        MemoryCacheManager.getInstance().putSerializableNoNotice(cacheKey(warnCode), mark);
    }

    static void remove(@NonNull String warnCode) {
        MemoryCacheManager.getInstance().remove(cacheKey(warnCode));
    }

    @VisibleForTesting
    static void resetForTest() {
        for (AlarmCodeEnums alarm : AlarmCodeEnums.values()) {
            remove(alarm.errorCode);
        }
    }

    @NonNull
    private static String cacheKey(@NonNull String warnCode) {
        return CacheKey.WARN_DIALOG_CLOSE_TIME_KEY + warnCode;
    }
}
