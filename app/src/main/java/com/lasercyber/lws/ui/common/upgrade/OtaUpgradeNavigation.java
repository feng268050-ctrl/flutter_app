package com.lasercyber.lws.ui.common.upgrade;

import android.content.Context;
import android.content.Intent;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.lasercyber.lws.ui.activitys.other.UpgradeActivity;
import com.lasercyber.lws.ui.bean.entity.DeviceInfo;
import com.lasercyber.lws.ui.common.version.SemanticVersionHelper;

/**
 * Shared navigation from a resolved OTA manifest to {@link UpgradeActivity}.
 */
public final class OtaUpgradeNavigation {

    private OtaUpgradeNavigation() {
    }

    @NonNull
    public static Intent buildUpgradeIntent(
            @NonNull Context context,
            @NonNull OtaUpdateManifestService.ManifestData manifest,
            @Nullable DeviceInfo deviceInfo
    ) {
        Intent intent = new Intent(context, UpgradeActivity.class);
        applyManifestExtras(intent, manifest, deviceInfo);
        return intent;
    }

    @VisibleForTesting
    static void applyManifestExtras(
            @NonNull Intent intent,
            @NonNull OtaUpdateManifestService.ManifestData manifest,
            @Nullable DeviceInfo deviceInfo
    ) {
        String remoteVer = manifest.version;
        String title = SemanticVersionHelper.resolveOtaUpgradeTitle(manifest.title, remoteVer);
        String content = manifest.content;
        intent.putExtra("title", title);
        intent.putExtra("content", content);
        intent.putExtra("version", remoteVer);
        intent.putExtra("downloadUrl", manifest.url);
        if (manifest.sha512 != null && !manifest.sha512.trim().isEmpty()) {
            intent.putExtra("sha512", manifest.sha512.trim());
        }
        if (deviceInfo != null) {
            intent.putExtra("info", deviceInfo);
        }
    }

    public static void startUpgradeActivity(
            @NonNull Context context,
            @NonNull OtaUpdateManifestService.ManifestData manifest,
            @Nullable DeviceInfo deviceInfo
    ) {
        context.startActivity(buildUpgradeIntent(context, manifest, deviceInfo));
    }
}
