package com.lasercyber.lws.ui.network.http.local;

import androidx.annotation.NonNull;
import androidx.annotation.VisibleForTesting;

import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.bean.entity.WarnTable;
import com.lasercyber.lws.ui.common.handler.WarnListLoader;

import java.util.Collections;
import java.util.List;

/**
 * Reference-counted SSE stream for {@code GET /v1/monitor/alerts}.
 */
public final class MonitorAlertsHttpPublisher {

    private static final MonitorAlertsHttpPublisher INSTANCE = new MonitorAlertsHttpPublisher();
    private final MonitorAlertsSseHub sseHub = new MonitorAlertsSseHub(MonitorAlertsHttpPublisher::loadWarnList);

    private MonitorAlertsHttpPublisher() {
    }

    @NonNull
    public static MonitorAlertsHttpPublisher getInstance() {
        return INSTANCE;
    }

    @NonNull
    public MonitorAlertsSseHub.SseSubscriber acquire() {
        return sseHub.acquireSubscriber();
    }

    @NonNull
    private static List<WarnTable> loadWarnList() {
        if (Utils.getApp() == null) {
            return Collections.emptyList();
        }
        return WarnListLoader.loadLocalizedWarnList(Utils.getApp());
    }

    @VisibleForTesting
    static void resetForTest() {
        INSTANCE.sseHub.resetForTest();
    }
}
