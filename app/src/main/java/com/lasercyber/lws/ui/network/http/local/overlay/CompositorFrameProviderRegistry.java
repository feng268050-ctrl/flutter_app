package com.lasercyber.lws.ui.network.http.local.overlay;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.lang.ref.WeakReference;

/**
 * Weak registry so {@link com.lasercyber.lws.ui.activitys.device.monitor.fragment.AiVisionFragment}
 * can supply frames without holding HTTP types.
 */
public final class CompositorFrameProviderRegistry {

    private static final CompositorFrameProviderRegistry INSTANCE = new CompositorFrameProviderRegistry();

    @Nullable
    private WeakReference<CompositorFrameProvider> providerRef;

    @NonNull
    public static CompositorFrameProviderRegistry getInstance() {
        return INSTANCE;
    }

    public void register(@Nullable CompositorFrameProvider provider) {
        providerRef = provider == null ? null : new WeakReference<>(provider);
    }

    @Nullable
    public CompositorFrameProvider getActiveProvider() {
        WeakReference<CompositorFrameProvider> ref = providerRef;
        if (ref == null) {
            return null;
        }
        CompositorFrameProvider provider = ref.get();
        if (provider == null || !provider.isActive()) {
            providerRef = null;
            return null;
        }
        return provider;
    }
}
