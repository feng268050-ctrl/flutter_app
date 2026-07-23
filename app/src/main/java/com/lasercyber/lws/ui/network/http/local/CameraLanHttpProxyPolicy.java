package com.lasercyber.lws.ui.network.http.local;

import android.content.Context;

import androidx.annotation.NonNull;
import androidx.annotation.VisibleForTesting;

import com.lasercyber.lws.ui.BuildConfig;
import com.lasercyber.lws.ui.common.config.AppRuntimeEnvironment;

/**
 * Staging / dev-only policy for {@link CameraLanHttpProxy}. Production release-channel APKs
 * never start the proxy (compile-time and effective tier).
 */
public final class CameraLanHttpProxyPolicy {

    private CameraLanHttpProxyPolicy() {
    }

    /** {@code true} when this APK was built for non-production OTA channel. */
    public static boolean isCompiledForNonProductionChannel() {
        return !BuildConfig.RELEASE_CHANNEL;
    }

    /**
     * Whether the LAN camera HTTP proxy may bind on this device right now.
     */
    public static boolean shouldRun(@NonNull Context context) {
        context.getApplicationContext();
        return shouldRun(isCompiledForNonProductionChannel(),
                AppRuntimeEnvironment.effectiveReleaseChannel());
    }

    @VisibleForTesting
    static boolean shouldRun(boolean compiledNonProduction, boolean effectiveReleaseChannel) {
        return compiledNonProduction && !effectiveReleaseChannel;
    }
}
