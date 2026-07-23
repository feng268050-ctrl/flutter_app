package com.lasercyber.lws.ui.network.ws;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.blankj.utilcode.util.ActivityUtils;
import com.blankj.utilcode.util.GsonUtils;
import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.BuildConfig;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.other.UpgradeActivity;
import com.lasercyber.lws.ui.bean.entity.ProcessParamsVideo;
import com.lasercyber.lws.ui.bean.entity.dto.DeviceRemoteSnapshot;
import com.lasercyber.lws.ui.bean.entity.vo.ProcessParamsVideoVo;
import com.lasercyber.lws.ui.bean.event.RemoteUpdateUiEvent;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.bean.push.ProcessParametersPushEnvelope;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.activitys.device.monitor.fragment.ProcessVideoFragment;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.network.proxy.ClientPurpose;
import com.lasercyber.lws.ui.common.network.proxy.NetworkHttpClientProvider;
import com.lasercyber.lws.ui.common.network.proxy.NetworkRoutePolicy;
import com.lasercyber.lws.ui.common.constant.ServerPushAckCode;
import com.lasercyber.lws.ui.common.device.DeviceIdentity;
import com.lasercyber.lws.ui.common.device.DeviceRemoteLockPolicy;
import com.lasercyber.lws.ui.common.device.DeviceRemoteLockStore;
import com.lasercyber.lws.ui.bean.entity.DeviceControlData;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusManagerRtu;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusFiledBuilder;
import com.lasercyber.lws.ui.common.utils.ProcessParameterDisplayRows;
import com.lasercyber.lws.ui.common.utils.DeviceQRCodeUtils;
import com.lasercyber.lws.ui.common.utils.json.GsonInitUtils;
import com.lasercyber.lws.ui.common.handler.MonitorListForegroundUploadCoordinator;
import com.lasercyber.lws.ui.common.handler.MonitorProcessVideoListUploadRunner;
import com.lasercyber.lws.ui.component.dialog.AutoDialogQueue;
import com.lasercyber.lws.ui.component.dialog.GlobalDialogUtil;
import com.lasercyber.lws.ui.common.handler.DeviceStatusPut;
import com.lasercyber.lws.ui.common.handler.WarnListLoader;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.upgrade.OtaUpdateManifestService;
import com.lasercyber.lws.ui.network.NetworkMonitor;
import com.lasercyber.lws.ui.network.channel.DeviceChannelProtocol;
import com.lasercyber.lws.ui.network.channel.DeviceChannelTelemetry;
import com.lasercyber.lws.ui.network.channel.DeviceChannelValidator;
import com.lasercyber.lws.ui.network.channel.DeviceCommandLifecycleTracker;
import com.lasercyber.lws.ui.network.channel.DeviceDataEvent;
import com.lasercyber.lws.ui.network.channel.ProcessLibraryPushPayload;
import com.lasercyber.lws.ui.network.channel.ServerPushMessageHandler;
import com.lasercyber.lws.ui.network.channel.ServerPushProcessLibPayloadParser;
import com.lasercyber.lws.ui.network.channel.ServerPushProcessParamPayloadParser;
import com.lasercyber.lws.ui.repository.ProcessProcessVideoDao;

import com.google.gson.JsonObject;
import com.google.gson.reflect.TypeToken;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;
import okhttp3.WebSocket;
import okhttp3.WebSocketListener;
import okio.ByteString;
import org.greenrobot.eventbus.EventBus;

public final class DeviceWebSocketConnectionManager {
    private static final String TAG = LogTAGConstant.DEVICE_WS;
    private static final long INITIAL_BACKOFF_MS = 1000L;
    private static final long MAX_BACKOFF_MS = 30000L;
    private static final int CLOSE_CODE_REPLACED = 4409;
    private static final int CLOSE_CODE_NORMAL = 1000;
    private static final String COMMAND_CHECK_UPDATE = "command.check_update";
    private static final String COMMAND_CHECK_UPDATE_ACK = "command.check_update_ack";
    private static final String COMMAND_UPDATE_SYSTEM = "command.update_system";
    private static final String COMMAND_UPDATE_SYSTEM_ACK = "command.update_system_ack";
    private static final String DEVICE_UPDATE_PROGRESS = "device.update_progress";
    /** Inbound server eviction; no outbound ACK until backend contract specifies one. */
    private static final String COMMAND_DISCONNECT = "command.disconnect";
    private static final String COMMAND_LOCK = "command.lock";
    private static final String COMMAND_UNLOCK = "command.unlock";
    private static final String COMMAND_CLEAR_ALERTS = "command.clear_alerts";
    private static final String COMMAND_CLEAR_ALERTS_ACK = "command.clear_alerts_ack";

    private static volatile DeviceWebSocketConnectionManager instance;

    private final ScheduledExecutorService scheduler = Executors.newSingleThreadScheduledExecutor();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    private volatile WebSocket webSocket;
    private volatile DeviceWsConnectionState state = DeviceWsConnectionState.IDLE;
    private volatile long reconnectAttempt = 0;
    /** Bumped on each intentional new connection or manual disconnect; stale listeners skip reconnect. */
    private volatile long connectionGeneration = 0L;
    private volatile ScheduledFuture<?> reconnectFuture;
    private volatile String activeUrl;
    private volatile String activeSn;
    private volatile String lastErrorCode;
    private final AtomicBoolean remoteUpdateInProgress = new AtomicBoolean(false);

    private DeviceWebSocketConnectionManager() {
    }

    private static OkHttpClient wsClient() {
        return NetworkHttpClientProvider.getInstance()
                .getClient(ClientPurpose.WEBSOCKET, NetworkRoutePolicy.INTERNET_PROXY_AWARE, null);
    }

    public static DeviceWebSocketConnectionManager getInstance() {
        if (instance == null) {
            synchronized (DeviceWebSocketConnectionManager.class) {
                if (instance == null) {
                    instance = new DeviceWebSocketConnectionManager();
                }
            }
        }
        return instance;
    }

    public synchronized void connectOrReconnect(String reason) {
        if (ForcedWsReconnectSuppression.isActive()) {
            Log.i(TAG, "device_ws skip connect: forced-disconnect suppression active (this process)");
            return;
        }
        String deviceSn = DeviceIdentity.getDeviceSnSafely();
        if (DeviceIdentity.UNKNOWN_SN.equals(deviceSn) || deviceSn == null || deviceSn.trim().isEmpty()) {
            lastErrorCode = "invalid_sn";
            transition(DeviceWsConnectionState.OFFLINE_AUTH_ERROR, "skip connect because device sn unavailable");
            return;
        }
        if (state == DeviceWsConnectionState.OFFLINE_AUTH_ERROR && "auth_invalid_sn".equals(lastErrorCode)) {
            Log.d(TAG, "device_ws skip connect: handshake returned HTTP 401, automatic reconnect disabled");
            return;
        }
        if (!NetworkMonitor.isNetworkAvailable(com.blankj.utilcode.util.Utils.getApp())) {
            transition(DeviceWsConnectionState.IDLE, "skip connect because network unavailable");
            scheduleReconnect("network_unavailable");
            return;
        }

        String wsUrl;
        try {
            wsUrl = DeviceWebSocketConfig.buildDeviceWsUrl(deviceSn);
        } catch (IllegalStateException ex) {
            lastErrorCode = "api_origin_pending";
            transition(DeviceWsConnectionState.IDLE, "skip connect because api origin not selected yet");
            scheduleReconnect("api_origin_pending");
            return;
        } catch (IllegalArgumentException ex) {
            lastErrorCode = "invalid_sn";
            transition(DeviceWsConnectionState.OFFLINE_AUTH_ERROR, "skip connect because " + ex.getMessage());
            return;
        }

        // Stale backoff from a prior failure can fire while a newer network_available handshake is in flight
        // or after transport is already ONLINE; without this it would cancel() a good socket.
        if ("backoff_retry".equals(reason)) {
            if (state == DeviceWsConnectionState.CONNECTING) {
                Log.d(TAG, "device_ws skip backoff_retry: handshake in progress");
                return;
            }
            if (state == DeviceWsConnectionState.ONLINE) {
                Log.d(TAG, "device_ws skip backoff_retry: session already online");
                return;
            }
        }

        // Rapid onAvailable is debounced on the API-origin probe path before this runs.
        // Remaining overlap (e.g. backoff vs probe completion) may still replace/cancel.
        this.activeUrl = wsUrl;
        this.activeSn = deviceSn;
        WebSocket previous = webSocket;
        connectionGeneration++;
        long generation = connectionGeneration;
        if (previous != null) {
            Log.d(TAG, "device_ws replacing existing connection, reason=" + reason);
            previous.cancel();
        }
        transition(state == DeviceWsConnectionState.ONLINE ? DeviceWsConnectionState.RECONNECTING : DeviceWsConnectionState.CONNECTING,
                "connect reason=" + reason);

        if ("network_available".equals(reason)) {
            Log.i(TAG, "device_ws open new socket (post api-origin probe), url=" + wsUrl);
        }

        Request request = new Request.Builder().url(wsUrl).build();
        webSocket = wsClient().newWebSocket(request, new DeviceWsListener(generation));
    }

    public synchronized void disconnect(String reason) {
        cancelReconnect();
        connectionGeneration++;
        WebSocket socket = webSocket;
        webSocket = null;
        if (socket != null) {
            Log.i(TAG, "device_ws manual disconnect, reason=" + reason);
            socket.close(CLOSE_CODE_NORMAL, "disconnect:" + reason);
        }
        reconnectAttempt = 0;
        transition(DeviceWsConnectionState.IDLE, "manual disconnect reason=" + reason);
    }

    public boolean isOnlineReady() {
        return state == DeviceWsConnectionState.ONLINE;
    }

    public DeviceWsConnectionState getState() {
        return state;
    }

    public long getReconnectAttempt() {
        return reconnectAttempt;
    }

    public String getLastErrorCode() {
        return lastErrorCode;
    }

    /**
     * User-initiated retry after WS 401 / unregistered device; clears auth-error latch then connects.
     */
    public void retryConnectAfterAuthError(String reason) {
        synchronized (this) {
            lastErrorCode = null;
            if (state == DeviceWsConnectionState.OFFLINE_AUTH_ERROR) {
                transition(DeviceWsConnectionState.IDLE, "user reconnect after 401");
            }
        }
        connectOrReconnect(reason != null ? reason : "user_reconnect_after_401");
    }

    public boolean sendCommandAck(String commandId, int code, String correlationId) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("command_id", commandId != null ? commandId : "");
        payload.put("correlation_id", correlationId != null ? correlationId : "");
        payload.put("code", code);
        String id = DeviceWebSocketEnvelope.newUniqueMessageId();
        String json = DeviceWebSocketEnvelope.toJson("ack", payload, id, System.currentTimeMillis());
        return sendRawJson(json);
    }

    /**
     * Ack for {@code command.send_process_param}: new outbound {@code id},
     * {@code payload.request_id} = server's inbound message id,
     * {@code payload.code}/{@code payload.message} report result.
     */
    public boolean sendProcessParamAck(String requestId, int code, String message) {
        String rid = requestId != null ? requestId : "";
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("request_id", rid);
        payload.put("code", code);
        payload.put("message", message != null ? message : "");
        String id = DeviceWebSocketEnvelope.newUniqueMessageId();
        String json = DeviceWebSocketEnvelope.toJson("command.send_process_param_ack", payload, id, System.currentTimeMillis());
        return sendRawJson(json);
    }

    /**
     * Ack for {@code command.send_process_lib}: new outbound {@code id},
     * {@code payload.request_id} = server's inbound message id,
     * {@code payload.code}/{@code payload.message} report result.
     */
    public boolean sendProcessLibAck(String requestId, int code, String message) {
        String rid = requestId != null ? requestId : "";
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("request_id", rid);
        payload.put("code", code);
        payload.put("message", message != null ? message : "");
        String id = DeviceWebSocketEnvelope.newUniqueMessageId();
        String json = DeviceWebSocketEnvelope.toJson("command.send_process_lib_ack", payload, id, System.currentTimeMillis());
        return sendRawJson(json);
    }

    /**
     * Reports process video upload progress to the server (payload keys camelCase, aligned with {@code ProcessParamsVideo}).
     */
    public boolean sendVideoUploading(@NonNull String videoId, int uploadStatus, int uploadProgress,
            @Nullable String videoUrl) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("videoId", videoId);
        payload.put("uploadStatus", uploadStatus);
        payload.put("uploadProgress", uploadProgress);
        payload.put("videoUrl", videoUrl != null ? videoUrl : "");
        String id = DeviceWebSocketEnvelope.newUniqueMessageId();
        String json = DeviceWebSocketEnvelope.toJson("video.uploading", payload, id, System.currentTimeMillis());
        return sendRawJson(json);
    }

    /**
     * Pushes catalog fields for one process-video row after cover upload (camelCase payload; no local id/path).
     */
    public boolean sendVideoMetadata(@NonNull ProcessParamsVideo row) {
        Map<String, Object> payload = DeviceWsVideoMetadataPayload.fromRow(row);
        String id = DeviceWebSocketEnvelope.newUniqueMessageId();
        String json = DeviceWebSocketEnvelope.toJson("video.metadata", payload, id, System.currentTimeMillis());
        return sendRawJson(json);
    }

    public boolean sendDeviceUpdateProgress(
            @NonNull String stage,
            int progress,
            @NonNull String status,
            @Nullable String message,
            @Nullable String errorCode
    ) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("stage", stage);
        payload.put("progress", Math.max(0, Math.min(progress, 100)));
        payload.put("status", status);
        if (message != null && !message.trim().isEmpty()) {
            payload.put("message", message.trim());
        }
        if (errorCode != null && !errorCode.trim().isEmpty()) {
            payload.put("error_code", errorCode.trim());
        }
        String id = DeviceWebSocketEnvelope.newUniqueMessageId();
        String json = DeviceWebSocketEnvelope.toJson(DEVICE_UPDATE_PROGRESS, payload, id, System.currentTimeMillis());
        boolean sent = sendRawJson(json);
        if (!sent) {
            Log.w(TAG, "device_ws device.update_progress send failed stage=" + stage
                    + " progress=" + progress + " status=" + status);
        }
        return sent;
    }

    public void markRemoteUpdateFlowFinished() {
        remoteUpdateInProgress.set(false);
    }

    private boolean sendRawJson(String payload) {
        WebSocket socket = webSocket;
        if (socket == null || !isOnlineReady()) {
            return false;
        }
        return socket.send(payload);
    }

    private void scheduleReconnect(String reason) {
        if (ForcedWsReconnectSuppression.isActive()) {
            Log.i(TAG, "device_ws skip scheduleReconnect: forced-disconnect suppression active");
            return;
        }
        reconnectAttempt++;
        long delayMs = computeBackoffMs(reconnectAttempt);
        transition(DeviceWsConnectionState.RECONNECTING, "schedule reconnect in " + delayMs + "ms, reason=" + reason);
        ScheduledFuture<?> previous = reconnectFuture;
        if (previous != null) {
            previous.cancel(false);
        }
        reconnectFuture = scheduler.schedule(() -> connectOrReconnect("backoff_retry"), delayMs, TimeUnit.MILLISECONDS);
    }

    private void cancelReconnect() {
        ScheduledFuture<?> task = reconnectFuture;
        reconnectFuture = null;
        if (task != null) {
            task.cancel(false);
        }
    }

    private void endConnectionFromListener(long listenerGeneration) {
        if (listenerGeneration != connectionGeneration) {
            return;
        }
        webSocket = null;
    }

    private void onInboundMessage(String text) {
        DeviceWebSocketEnvelope.Parsed env = DeviceWebSocketEnvelope.parse(text);
        if (env == null) {
            Log.w(TAG, "device_ws dropped invalid envelope frame");
            return;
        }
        if (env.v != DeviceWebSocketEnvelope.PROTOCOL_VERSION) {
            Log.w(TAG, "device_ws dropped frame with unsupported v=" + env.v);
            return;
        }
        String type = env.type;
        if ("connected".equals(type)) {
            Log.d(TAG, "device_ws ignoring legacy connected frame (online uses transport open)");
            return;
        }

        if (COMMAND_DISCONNECT.equals(type)) {
            Log.i(TAG, "device_ws command.disconnect id=" + env.id + " ts=" + env.ts);
            handleInboundForcedDisconnect(env);
            return;
        }

        if (COMMAND_LOCK.equals(type)) {
            Log.i(TAG, "device_ws command.lock id=" + env.id + " ts=" + env.ts);
            handleInboundRemoteLock(true);
            return;
        }

        if (COMMAND_UNLOCK.equals(type)) {
            Log.i(TAG, "device_ws command.unlock id=" + env.id + " ts=" + env.ts);
            handleInboundRemoteLock(false);
            return;
        }

        if ("ack".equals(type)) {
            String correlationId = DeviceWebSocketEnvelope.payloadString(env.payload, "correlation_id");
            if (correlationId != null && !correlationId.trim().isEmpty()) {
                DeviceCommandLifecycleTracker.markAcknowledged(correlationId);
            }
            return;
        }

        if ("command.send_process_param".equals(type)) {
            handleInboundSendProcessParam(env);
            return;
        }

        if ("command.send_process_lib".equals(type)) {
            handleInboundSendProcessLib(env);
            return;
        }

        if (COMMAND_CLEAR_ALERTS.equals(type)) {
            Log.i(TAG, "device_ws clear_alerts id=" + env.id + " ts=" + env.ts);
            handleInboundClearAlerts(env);
            return;
        }

        if ("command.stat_request".equals(type)) {
            Log.i(TAG, "device_ws stat_request id=" + env.id + " ts=" + env.ts);
            handleInboundStatRequest(env);
            return;
        }

        if ("command.video_list_request".equals(type)) {
            Log.i(TAG, "device_ws video_list_request id=" + env.id + " ts=" + env.ts);
            handleInboundVideoListRequest(env);
            return;
        }

        if ("command.upload_video".equals(type)) {
            Log.i(TAG, "device_ws upload_video id=" + env.id + " ts=" + env.ts);
            handleInboundUploadVideo(env);
            return;
        }

        if ("command.delete_video".equals(type)) {
            Log.i(TAG, "device_ws delete_video id=" + env.id + " ts=" + env.ts);
            handleInboundDeleteVideo(env);
            return;
        }

        if ("command.process_library_request".equals(type)) {
            Log.i(TAG, "device_ws process_library_request id=" + env.id + " ts=" + env.ts);
            handleInboundProcessLibraryRequest(env);
            return;
        }

        if ("command.process_parameters_request".equals(type)) {
            Log.i(TAG, "device_ws process_parameters_request id=" + env.id + " ts=" + env.ts);
            handleInboundProcessParametersRequest(env);
            return;
        }

        if ("command.process_parameters_create".equals(type)) {
            Log.i(TAG, "device_ws process_parameters_create id=" + env.id + " ts=" + env.ts);
            handleInboundProcessParametersCreate(env);
            return;
        }

        if ("command.process_parameters_update".equals(type)) {
            Log.i(TAG, "device_ws process_parameters_update id=" + env.id + " ts=" + env.ts);
            handleInboundProcessParametersUpdate(env);
            return;
        }

        if ("command.process_parameters_delete".equals(type)) {
            Log.i(TAG, "device_ws process_parameters_delete id=" + env.id + " ts=" + env.ts);
            handleInboundProcessParametersDelete(env);
            return;
        }

        if ("command.process_parameters_set_default".equals(type)) {
            Log.i(TAG, "device_ws process_parameters_set_default id=" + env.id + " ts=" + env.ts);
            handleInboundProcessParametersSetDefault(env);
            return;
        }

        if (COMMAND_CHECK_UPDATE.equals(type)) {
            Log.i(TAG, "device_ws command.check_update id=" + env.id + " ts=" + env.ts);
            handleInboundCheckUpdate(env);
            return;
        }

        if (COMMAND_UPDATE_SYSTEM.equals(type)) {
            Log.i(TAG, "device_ws command.update_system id=" + env.id + " ts=" + env.ts);
            handleInboundUpdateSystem(env);
            return;
        }

        if ("command".equals(type)) {
            String commandId = DeviceWebSocketEnvelope.payloadString(env.payload, "command_id");
            String correlationId = DeviceWebSocketEnvelope.payloadString(env.payload, "correlation_id");
            sendCommandAck(commandId != null ? commandId : "", 0, correlationId != null ? correlationId : "");
        }
    }

    private void handleInboundRemoteLock(boolean locked) {
        DeviceRemoteLockStore.setLocked(locked);
        if (locked) {
            applyRemoteLockSafetyStop();
        }
        mainHandler.post(() -> {
            if (locked) {
                DeviceRemoteLockPolicy.onRemoteLockAppliedFromServer();
            } else {
                DeviceRemoteLockPolicy.onRemoteUnlockAppliedFromServer();
            }
        });
    }

    /**
     * Remote lock must immediately block emission (laser enable off).
     *
     * <p>We explicitly clear CONTROL_FIELD_1 (0x0058) Bit0 by writing a control-switch payload with
     * {@code laserStatus=0}. For safety, other control bits are cleared as well (manual gas/feed).</p>
     */
    private void applyRemoteLockSafetyStop() {
        try {
            DeviceControlData control = new DeviceControlData()
                    .setLaserStatus(0)
                    .setManualGas(0)
                    .setWireFeedEnable(0)
                    .setWireFeedDirection(0)
                    .setAutoWireFeedEnable(0);
            ModbusManagerRtu.get().writeRegisters(ModbusFiledBuilder.createDeviceControlSwitchData(control));
        } catch (Exception ex) {
            Log.w(TAG, "device_ws remote lock: failed to write CONTROL_FIELD_1 safety stop", ex);
        }
    }

    private void handleInboundForcedDisconnect(DeviceWebSocketEnvelope.Parsed env) {
        String reasonPart = DeviceWebSocketEnvelope.payloadString(env.payload, "reason");
        String reason = reasonPart != null ? reasonPart : "";
        Context app = Utils.getApp();
        ForcedWsReconnectSuppression.arm();
        synchronized (this) {
            cancelReconnect();
            connectionGeneration++;
            WebSocket socket = webSocket;
            webSocket = null;
            if (socket != null) {
                Log.i(TAG, "device_ws closing socket after command.disconnect id=" + env.id);
                socket.close(CLOSE_CODE_NORMAL, "command.disconnect");
            }
            reconnectAttempt = 0;
            transition(DeviceWsConnectionState.IDLE, "command.disconnect");
        }
        final String message = ForcedWsDisconnectMessage.body(reason);
        if (app != null) {
            mainHandler.post(() -> showForcedDisconnectDialog(message));
        }
    }

    private void showForcedDisconnectDialog(String message) {
        Activity top = ActivityUtils.getTopActivity();
        if (top == null || top.isFinishing() || top.isDestroyed()) {
            Log.w(TAG, "device_ws forced disconnect: skip dialog (no top activity or finishing)");
            return;
        }
        AutoDialogQueue.get().enqueueForcedWsDisconnect(
                top,
                ForcedWsDisconnectMessage.TITLE,
                message);
    }

    private void notifyAuthRegistrationRequired() {
        mainHandler.post(this::showDeviceRegistrationDialog);
    }

    private void showDeviceRegistrationDialog() {
        Activity top = ActivityUtils.getTopActivity();
        if (top == null || top.isFinishing() || top.isDestroyed()) {
            Log.w(TAG, "device_ws auth 401: skip registration dialog (no top activity or finishing)");
            return;
        }
        Bitmap qr = DeviceQRCodeUtils.createDeviceIdentityQrCodeV2(280, 280);
        AutoDialogQueue.get().enqueueDeviceRegistration(
                top,
                top.getString(R.string.ws_register_device_dialog_title),
                top.getString(R.string.ws_register_device_dialog_message),
                qr,
                () -> retryConnectAfterAuthError("user_reconnect_after_401"));
    }

    private void handleInboundClearAlerts(DeviceWebSocketEnvelope.Parsed env) {
        if (!isOnlineReady()) {
            Log.w(TAG, "device_ws ignoring command.clear_alerts while not online, id=" + env.id);
            return;
        }
        final String requestId = env.id != null ? env.id : "";
        if (requestId.trim().isEmpty()) {
            Log.w(TAG, "device_ws dropped command.clear_alerts without usable id");
            return;
        }
        final Context appContext = Utils.getApp();
        if (appContext == null) {
            Log.w(TAG, "device_ws dropped command.clear_alerts: application context unavailable");
            return;
        }
        ThreadPoolManager.getExecutor().execute(() -> {
            try {
                WarnListLoader.performClearAll(appContext);
                sendClearAlertsAck(requestId, true, "");
            } catch (Exception ex) {
                Log.e(TAG, "device_ws command.clear_alerts failed, request_id=" + requestId, ex);
                String msg = ex.getMessage() != null ? ex.getMessage() : "clear_failed";
                sendClearAlertsAck(requestId, false, msg);
            }
        });
    }

    private void handleInboundStatRequest(DeviceWebSocketEnvelope.Parsed env) {
        if (!isOnlineReady()) {
            Log.w(TAG, "device_ws ignoring command.stat_request while not online, id=" + env.id);
            return;
        }
        final String requestId = env.id;
        if (requestId == null || requestId.trim().isEmpty()) {
            Log.w(TAG, "device_ws dropped command.stat_request without usable id");
            return;
        }
        final Context appContext = Utils.getApp();
        if (appContext == null) {
            Log.w(TAG, "device_ws dropped command.stat_request: application context unavailable");
            return;
        }
        ThreadPoolManager.getExecutor().execute(() -> {
            try {
                DeviceRemoteSnapshot snapshot = new DeviceStatusPut().packRemoteSnapshot(appContext);
                sendStatResponse(requestId, snapshot);
            } catch (Exception ex) {
                Log.e(TAG, "device_ws command.stat_request handling failed, request_id=" + requestId, ex);
            }
        });
    }

    private void handleInboundUploadVideo(DeviceWebSocketEnvelope.Parsed env) {
        if (!isOnlineReady()) {
            Log.w(TAG, "device_ws ignoring command.upload_video while not online, id=" + env.id);
            return;
        }
        final String requestId = env.id != null ? env.id : "";
        if (requestId.trim().isEmpty()) {
            Log.w(TAG, "device_ws dropped command.upload_video without usable id");
            return;
        }
        final Context appContext = Utils.getApp();
        if (appContext == null) {
            Log.w(TAG, "device_ws dropped command.upload_video: application context unavailable");
            return;
        }
        String videoId = DeviceWebSocketEnvelope.payloadString(env.payload, "videoId");
        if (videoId == null || videoId.trim().isEmpty()) {
            sendUploadVideoAck(requestId, false, "missing_videoId");
            return;
        }
        final String videoIdTrim = videoId.trim();
        ThreadPoolManager.getExecutor().execute(() -> {
            try {
                ProcessProcessVideoDao dao = AppDatabase.getInstance(appContext).processProcessVideoDao();
                ProcessParamsVideo row = dao.selectByVideoId(videoIdTrim);
                if (row == null) {
                    sendUploadVideoAck(requestId, false, "video_not_found");
                    return;
                }
                long rowId = row.getId();
                mainHandler.post(() -> startUploadVideoAfterResolved(rowId, requestId));
            } catch (Exception ex) {
                Log.e(TAG, "device_ws command.upload_video failed, request_id=" + requestId, ex);
                String msg = ex.getMessage() != null ? ex.getMessage() : "lookup_failed";
                sendUploadVideoAck(requestId, false, msg);
            }
        });
    }

    private void handleInboundCheckUpdate(DeviceWebSocketEnvelope.Parsed env) {
        if (!isOnlineReady()) {
            Log.w(TAG, "device_ws ignoring command.check_update while not online, id=" + env.id);
            return;
        }
        final String requestId = env.id != null ? env.id.trim() : "";
        if (requestId.isEmpty()) {
            Log.w(TAG, "device_ws dropped command.check_update without usable id");
            return;
        }
        ThreadPoolManager.getExecutor().execute(() -> {
            try {
                OtaUpdateManifestService.CheckResult result = OtaUpdateManifestService.checkAgainst(BuildConfig.VERSION_NAME);
                Map<String, Object> manifest = result.manifest != null ? result.manifest.toWsManifestPayload() : null;
                sendCheckUpdateAck(requestId, true, result.hasUpdate, manifest, null, null);
            } catch (Exception ex) {
                Log.e(TAG, "device_ws command.check_update failed, request_id=" + requestId, ex);
                sendCheckUpdateAck(requestId, false, false, null, "check_failed",
                        ex.getMessage() != null ? ex.getMessage() : "check_failed");
            }
        });
    }

    private void handleInboundUpdateSystem(DeviceWebSocketEnvelope.Parsed env) {
        if (!isOnlineReady()) {
            Log.w(TAG, "device_ws ignoring command.update_system while not online, id=" + env.id);
            return;
        }
        final String requestId = env.id != null ? env.id.trim() : "";
        if (requestId.isEmpty()) {
            Log.w(TAG, "device_ws dropped command.update_system without usable id");
            return;
        }
        if (!remoteUpdateInProgress.compareAndSet(false, true)) {
            sendUpdateSystemAck(requestId, false, false, "update_in_progress", "update flow already running");
            mainHandler.post(() -> EventBus.getDefault().post(RemoteUpdateUiEvent.updateRejected("update flow already running")));
            return;
        }
        Map<String, String> manifest = parseUpdateSystemManifest(env.payload);
        if (!OtaUpdateManifestService.isValidInboundSystemManifestPayload(manifest)) {
            remoteUpdateInProgress.set(false);
            sendUpdateSystemAck(requestId, false, false, "invalid_payload", "manifest fields are required");
            mainHandler.post(() -> EventBus.getDefault().post(RemoteUpdateUiEvent.updateRejected("manifest fields are required")));
            return;
        }
        final Context appContext = Utils.getApp();
        if (appContext == null) {
            remoteUpdateInProgress.set(false);
            sendUpdateSystemAck(requestId, false, false, "app_context_unavailable", "application context unavailable");
            mainHandler.post(() -> EventBus.getDefault().post(RemoteUpdateUiEvent.updateRejected("application context unavailable")));
            return;
        }
        try {
            Intent intent = new Intent(appContext, UpgradeActivity.class);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
            String title = safeManifestText(manifest, "title");
            String content = safeManifestText(manifest, "content");
            intent.putExtra("title", title.isEmpty() ? manifest.get("version") : title);
            intent.putExtra("content", content.isEmpty() ? "Remote update command accepted" : content);
            intent.putExtra("version", manifest.get("version"));
            intent.putExtra("downloadUrl", manifest.get("url"));
            intent.putExtra("sha512", manifest.get("sha512"));
            intent.putExtra("remoteAutoStart", true);
            mainHandler.post(() -> EventBus.getDefault().post(RemoteUpdateUiEvent.updateTriggered(manifest.get("version"))));
            appContext.startActivity(intent);
            sendUpdateSystemAck(requestId, true, true, null, null);
        } catch (Exception ex) {
            remoteUpdateInProgress.set(false);
            Log.e(TAG, "device_ws command.update_system failed to start upgrade activity", ex);
            sendUpdateSystemAck(requestId, false, false, "start_failed",
                    ex.getMessage() != null ? ex.getMessage() : "start_failed");
            mainHandler.post(() -> EventBus.getDefault().post(RemoteUpdateUiEvent.updateRejected(
                    ex.getMessage() != null ? ex.getMessage() : "start_failed"
            )));
        }
    }

    private Map<String, String> parseUpdateSystemManifest(@Nullable JsonObject payload) {
        if (payload == null) {
            return null;
        }
        try {
            // command.update_system payload is the manifest object itself (no nested payload.manifest).
            return GsonUtils.fromJson(payload.toString(), new TypeToken<Map<String, String>>() {
            }.getType());
        } catch (Exception ex) {
            Log.w(TAG, "device_ws invalid command.update_system manifest payload", ex);
            return null;
        }
    }

    private static String safeManifestText(@Nullable Map<String, String> manifest, @NonNull String key) {
        if (manifest == null) {
            return "";
        }
        String value = manifest.get(key);
        return value == null ? "" : value.trim();
    }

    public boolean sendCheckUpdateAck(
            @NonNull String requestId,
            boolean ok,
            boolean hasUpdate,
            @Nullable Map<String, Object> manifest,
            @Nullable String errorCode,
            @Nullable String errorMessage
    ) {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("ok", ok);
        data.put("has_update", hasUpdate);
        if (manifest != null && hasUpdate) {
            data.put("manifest", manifest);
        }
        if (errorCode != null && !errorCode.trim().isEmpty()) {
            data.put("error_code", errorCode);
        }
        if (errorMessage != null && !errorMessage.trim().isEmpty()) {
            data.put("error_message", errorMessage);
        }
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("request_id", requestId);
        payload.put("data", data);
        String id = DeviceWebSocketEnvelope.newUniqueMessageId();
        String json = DeviceWebSocketEnvelope.toJson(COMMAND_CHECK_UPDATE_ACK, payload, id, System.currentTimeMillis());
        return sendRawJson(json);
    }

    public boolean sendUpdateSystemAck(
            @NonNull String requestId,
            boolean ok,
            boolean started,
            @Nullable String errorCode,
            @Nullable String errorMessage
    ) {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("ok", ok);
        data.put("started", started);
        if (errorCode != null && !errorCode.trim().isEmpty()) {
            data.put("error_code", errorCode);
        }
        if (errorMessage != null && !errorMessage.trim().isEmpty()) {
            data.put("error_message", errorMessage);
        }
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("request_id", requestId);
        payload.put("data", data);
        String id = DeviceWebSocketEnvelope.newUniqueMessageId();
        String json = DeviceWebSocketEnvelope.toJson(COMMAND_UPDATE_SYSTEM_ACK, payload, id, System.currentTimeMillis());
        return sendRawJson(json);
    }

    /**
     * Outbound {@code command.upload_video_ack}: new top-level {@code id},
     * {@code payload.request_id} = inbound {@code command.upload_video} top-level {@code id},
     * {@code payload.data} = {@code { success, message }}.
     */
    public boolean sendUploadVideoAck(String requestId, boolean success, String message) {
        return sendCommandDataAck("command.upload_video_ack", requestId, success, message);
    }

    /**
     * Outbound {@code command.delete_video_ack}: same {@code payload} shape as {@link #sendUploadVideoAck}.
     */
    public boolean sendDeleteVideoAck(String requestId, boolean success, String message) {
        return sendCommandDataAck("command.delete_video_ack", requestId, success, message);
    }

    public boolean sendClearAlertsAck(String requestId, boolean success, String message) {
        return sendCommandDataAck(COMMAND_CLEAR_ALERTS_ACK, requestId, success, message);
    }

    private boolean sendCommandDataAck(String type, String requestId, boolean success, String message) {
        return sendProcessParametersMutationAck(type, requestId, success, message, null);
    }

    private boolean sendProcessParametersMutationAck(
            String type,
            String requestId,
            boolean success,
            String message,
            @Nullable Long createdRowId
    ) {
        String rid = requestId != null ? requestId : "";
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("success", success);
        data.put("message", message != null ? message : "");
        if (success && createdRowId != null) {
            data.put("id", DeviceWsRowId.toStringId(createdRowId));
        }
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("request_id", rid);
        payload.put("data", data);
        String id = DeviceWebSocketEnvelope.newUniqueMessageId();
        String json = DeviceWebSocketEnvelope.toJson(type, payload, id, System.currentTimeMillis());
        return sendRawJson(json);
    }

    private void startUploadVideoAfterResolved(long rowId, String requestId) {
        if (!isOnlineReady()) {
            sendUploadVideoAck(requestId, false, "not_online");
            return;
        }
        boolean ui = ProcessVideoFragment.tryStartUploadFromWebSocketCommand(rowId);
        if (!ui) {
            startUploadVideoHeadless(rowId);
        }
        sendUploadVideoAck(requestId, true, "");
    }

    private void startUploadVideoHeadless(long rowId) {
        MonitorListForegroundUploadCoordinator.get().start(Utils.getApp(), rowId, mainHandler,
                new MonitorProcessVideoListUploadRunner.Listener() {
                    @Override
                    public void onMetadataPhaseStarted() {
                    }

                    @Override
                    public void onVideoProgress(int percent0to100, @Nullable String detail) {
                    }

                    @Override
                    public void onFinishedSuccess(@Nullable String videoPublicUrl) {
                        // Row upload state is persisted via uploadStatus / videoUrl in the upload pipeline.
                    }

                    @Override
                    public void onFinishedError(@Nullable String msg) {
                        Log.w(TAG, "device_ws headless upload finished error rowId=" + rowId + " msg=" + msg);
                    }
                });
    }

    private void handleInboundDeleteVideo(DeviceWebSocketEnvelope.Parsed env) {
        final String requestId = env.id;
        if (requestId == null || requestId.trim().isEmpty()) {
            Log.w(TAG, "device_ws dropped command.delete_video without usable id");
            return;
        }
        final Context appContext = Utils.getApp();
        if (appContext == null) {
            Log.w(TAG, "device_ws dropped command.delete_video: application context unavailable");
            return;
        }
        JsonObject payload = env.payload;
        String videoId = payload != null && payload.has("video_id") && !payload.get("video_id").isJsonNull()
                ? payload.get("video_id").getAsString()
                : null;
        if (videoId == null || videoId.trim().isEmpty()) {
            sendDeleteVideoAck(requestId, false, "missing_video_id");
            return;
        }
        final String vid = videoId.trim();
        ThreadPoolManager.getExecutor().execute(() -> {
            try {
                com.lasercyber.lws.ui.common.handler.ProcessVideoDeleteHelper.Outcome outcome =
                        com.lasercyber.lws.ui.common.handler.ProcessVideoDeleteHelper.deleteByVideoId(
                                appContext, vid);
                switch (outcome) {
                    case SUCCESS -> sendDeleteVideoAck(requestId, true, "");
                    case FILE_DELETE_FAILED -> sendDeleteVideoAck(requestId, false, "file_delete_failed");
                    case NOT_FOUND -> sendDeleteVideoAck(requestId, false, "video_not_found");
                    default -> sendDeleteVideoAck(requestId, false, "delete_failed");
                }
            } catch (Exception ex) {
                Log.e(TAG, "device_ws command.delete_video failed, request_id=" + requestId, ex);
                sendDeleteVideoAck(requestId, false, "delete_failed");
            }
        });
    }

    private void handleInboundVideoListRequest(DeviceWebSocketEnvelope.Parsed env) {
        if (!isOnlineReady()) {
            Log.w(TAG, "device_ws ignoring command.video_list_request while not online, id=" + env.id);
            return;
        }
        final String requestId = env.id;
        if (requestId == null || requestId.trim().isEmpty()) {
            Log.w(TAG, "device_ws dropped command.video_list_request without usable id");
            return;
        }
        final Context appContext = Utils.getApp();
        if (appContext == null) {
            Log.w(TAG, "device_ws dropped command.video_list_request: application context unavailable");
            return;
        }
        final JsonObject payload = env.payload;
        ThreadPoolManager.getExecutor().execute(() -> {
            try {
                int[] pageParams = DeviceWsVideoListPayload.normalizePageAndSize(payload);
                DeviceWsVideoListPayload.ListFilters filters =
                        DeviceWsVideoListPayload.parseListFilters(payload);
                ProcessProcessVideoDao dao = AppDatabase.getInstance(appContext).processProcessVideoDao();
                com.lasercyber.lws.ui.network.http.local.ProcessVideoQueryService.PagedVideos page =
                        com.lasercyber.lws.ui.network.http.local.ProcessVideoQueryService.list(
                                dao, pageParams[0], pageParams[1], filters);
                sendVideoListResponse(requestId, page.list, page.total);
            } catch (Exception ex) {
                Log.e(TAG, "device_ws command.video_list_request handling failed, request_id=" + requestId, ex);
            }
        });
    }

    /**
     * Outbound {@code command.video_list_response}: new top-level {@code id},
     * {@code payload.request_id} = server's inbound message id,
     * {@code payload.data} = {@code { list, total }}.
     */
    public boolean sendVideoListResponse(String requestId, List<Map<String, Object>> list, long total) {
        String rid = requestId != null ? requestId : "";
        Map<String, Object> dataMap = new LinkedHashMap<>();
        dataMap.put("list", list != null ? list : new ArrayList<>());
        dataMap.put("total", total);
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("request_id", rid);
        payload.put("data", dataMap);
        String id = DeviceWebSocketEnvelope.newUniqueMessageId();
        long ts = System.currentTimeMillis();
        String json = DeviceWebSocketEnvelope.toJson("command.video_list_response", payload, id, ts);
        int jsonLen = json != null ? json.length() : 0;
        boolean ok = sendRawJson(json);
        if (ok) {
            Log.i(TAG, "device_ws video_list_response sent outboundId=" + id + " request_id=" + rid + " jsonLen=" + jsonLen);
        } else {
            Log.w(TAG, "device_ws video_list_response failed outboundId=" + id + " request_id=" + rid + " jsonLen=" + jsonLen
                    + " (socket null or not ONLINE)");
        }
        return ok;
    }

    /**
     * Outbound {@code command.process_library_response}: {@code payload.data} is an array of summary rows.
     */
    public boolean sendProcessLibraryResponse(String requestId, List<Map<String, Object>> list) {
        String rid = requestId != null ? requestId : "";
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("request_id", rid);
        payload.put("data", list != null ? list : new ArrayList<>());
        String id = DeviceWebSocketEnvelope.newUniqueMessageId();
        String json = DeviceWebSocketEnvelope.toJson("command.process_library_response", payload, id,
                System.currentTimeMillis());
        return sendRawJson(json);
    }

    /**
     * Outbound {@code command.process_parameters_response}: {@code payload.data} is one object or null.
     */
    public boolean sendProcessParametersResponse(String requestId, @Nullable Map<String, Object> data) {
        String rid = requestId != null ? requestId : "";
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("request_id", rid);
        payload.put("data", data);
        String id = DeviceWebSocketEnvelope.newUniqueMessageId();
        String json = DeviceWebSocketEnvelope.toJson("command.process_parameters_response", payload, id,
                System.currentTimeMillis());
        return sendRawJson(json);
    }

    private void handleInboundProcessLibraryRequest(DeviceWebSocketEnvelope.Parsed env) {
        if (!isOnlineReady()) {
            Log.w(TAG, "device_ws ignoring command.process_library_request while not online, id=" + env.id);
            return;
        }
        final String requestId = env.id;
        if (requestId == null || requestId.trim().isEmpty()) {
            Log.w(TAG, "device_ws dropped command.process_library_request without usable id");
            return;
        }
        final Context appContext = Utils.getApp();
        if (appContext == null) {
            Log.w(TAG, "device_ws dropped command.process_library_request: application context unavailable");
            return;
        }
        final JsonObject payload = env.payload;
        ThreadPoolManager.getExecutor().execute(() -> {
            try {
                Integer processType = DeviceWsProcessParametersPayload.parseProcessType(payload);
                if (processType == null) {
                    sendProcessLibraryResponse(requestId, new ArrayList<>());
                    return;
                }
                var dao = AppDatabase.getInstance(appContext).processParametersDataDao();
                List<Map<String, Object>> list = com.lasercyber.lws.ui.network.http.local
                        .ProcessParametersRemoteService.listLibrary(dao, processType, true);
                sendProcessLibraryResponse(requestId, list);
            } catch (Exception ex) {
                Log.e(TAG, "device_ws command.process_library_request failed, request_id=" + requestId, ex);
                sendProcessLibraryResponse(requestId, new ArrayList<>());
            }
        });
    }

    private void handleInboundProcessParametersRequest(DeviceWebSocketEnvelope.Parsed env) {
        if (!isOnlineReady()) {
            return;
        }
        final String requestId = env.id;
        if (requestId == null || requestId.trim().isEmpty()) {
            return;
        }
        final Context appContext = Utils.getApp();
        if (appContext == null) {
            return;
        }
        final JsonObject payload = env.payload;
        ThreadPoolManager.getExecutor().execute(() -> {
            Long rowId = DeviceWsRowId.parse(payload, "id");
            if (rowId == null) {
                sendProcessParametersResponse(requestId, null);
                return;
            }
            var dao = AppDatabase.getInstance(appContext).processParametersDataDao();
            var row = com.lasercyber.lws.ui.network.http.local.ProcessParametersRemoteService.getById(dao, rowId);
            sendProcessParametersResponse(requestId,
                    DeviceWsProcessParametersPayload.entityToMap(row, true));
        });
    }

    private void handleInboundProcessParametersCreate(DeviceWebSocketEnvelope.Parsed env) {
        if (!isOnlineReady()) {
            return;
        }
        final String requestId = env.id;
        if (requestId == null || requestId.trim().isEmpty()) {
            return;
        }
        final Context appContext = Utils.getApp();
        if (appContext == null) {
            return;
        }
        final JsonObject payload = env.payload != null ? env.payload : new JsonObject();
        ThreadPoolManager.getExecutor().execute(() -> {
            var dao = AppDatabase.getInstance(appContext).processParametersDataDao();
            var result = com.lasercyber.lws.ui.network.http.local.ProcessParametersRemoteService
                    .createFromJson(dao, payload, true);
            sendProcessParametersMutationAck(
                    "command.process_parameters_create_ack",
                    requestId,
                    result.success,
                    result.message,
                    result.success ? result.id : null);
        });
    }

    private void handleInboundProcessParametersUpdate(DeviceWebSocketEnvelope.Parsed env) {
        if (!isOnlineReady()) {
            return;
        }
        final String requestId = env.id;
        if (requestId == null || requestId.trim().isEmpty()) {
            return;
        }
        final Context appContext = Utils.getApp();
        if (appContext == null) {
            return;
        }
        final JsonObject payload = env.payload != null ? env.payload : new JsonObject();
        ThreadPoolManager.getExecutor().execute(() -> {
            Long rowId = DeviceWsRowId.parse(payload, "id");
            if (rowId == null) {
                sendProcessParametersMutationAck(
                        "command.process_parameters_update_ack", requestId, false, "invalid_id", null);
                return;
            }
            var dao = AppDatabase.getInstance(appContext).processParametersDataDao();
            var result = com.lasercyber.lws.ui.network.http.local.ProcessParametersRemoteService
                    .updateFromJson(dao, rowId, payload, true);
            sendProcessParametersMutationAck(
                    "command.process_parameters_update_ack",
                    requestId,
                    result.success,
                    result.message,
                    null);
        });
    }

    private void handleInboundProcessParametersDelete(DeviceWebSocketEnvelope.Parsed env) {
        if (!isOnlineReady()) {
            return;
        }
        final String requestId = env.id;
        if (requestId == null || requestId.trim().isEmpty()) {
            return;
        }
        final Context appContext = Utils.getApp();
        if (appContext == null) {
            return;
        }
        final JsonObject payload = env.payload;
        ThreadPoolManager.getExecutor().execute(() -> {
            Long rowId = DeviceWsRowId.parse(payload, "id");
            if (rowId == null) {
                sendProcessParametersMutationAck(
                        "command.process_parameters_delete_ack", requestId, false, "invalid_id", null);
                return;
            }
            var dao = AppDatabase.getInstance(appContext).processParametersDataDao();
            var result = com.lasercyber.lws.ui.network.http.local.ProcessParametersRemoteService.delete(dao, rowId);
            sendProcessParametersMutationAck(
                    "command.process_parameters_delete_ack",
                    requestId,
                    result.success,
                    result.message,
                    null);
        });
    }

    private void handleInboundProcessParametersSetDefault(DeviceWebSocketEnvelope.Parsed env) {
        if (!isOnlineReady()) {
            return;
        }
        final String requestId = env.id;
        if (requestId == null || requestId.trim().isEmpty()) {
            return;
        }
        final Context appContext = Utils.getApp();
        if (appContext == null) {
            return;
        }
        final JsonObject payload = env.payload;
        ThreadPoolManager.getExecutor().execute(() -> {
            Long rowId = DeviceWsRowId.parse(payload, "id");
            if (rowId == null) {
                sendProcessParametersMutationAck(
                        "command.process_parameters_set_default_ack", requestId, false, "invalid_id", null);
                return;
            }
            var dao = AppDatabase.getInstance(appContext).processParametersDataDao();
            var result = com.lasercyber.lws.ui.network.http.local.ProcessParametersRemoteService
                    .setDefault(dao, rowId);
            sendProcessParametersMutationAck(
                    "command.process_parameters_set_default_ack",
                    requestId,
                    result.success,
                    result.message,
                    null);
        });
    }

    /**
     * Outbound {@code command.stat_response}: new top-level {@code id},
     * {@code payload.request_id} = server's inbound message id,
     * {@code payload.data} = remote snapshot (no top-level {@code device}).
     */
    public boolean sendStatResponse(String requestId, DeviceRemoteSnapshot snapshot) {
        String rid = requestId != null ? requestId : "";
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("request_id", rid);
        payload.put("data", buildSnapshotDataMap(snapshot));
        String id = DeviceWebSocketEnvelope.newUniqueMessageId();
        long ts = System.currentTimeMillis();
        String json = DeviceWebSocketEnvelope.toJson("command.stat_response", payload, id, ts);
        int jsonLen = json != null ? json.length() : 0;
        boolean ok = sendRawJson(json);
        if (ok) {
            Log.i(TAG, "device_ws stat_response sent outboundId=" + id + " request_id=" + rid + " jsonLen=" + jsonLen);
        } else {
            Log.w(TAG, "device_ws stat_response failed outboundId=" + id + " request_id=" + rid + " jsonLen=" + jsonLen
                    + " (socket null or not ONLINE)");
        }
        return ok;
    }

    /**
     * Outbound {@code device.online}: unified envelope; {@code payload.stat} is the remote snapshot object
     * (same JSON as {@code command.stat_response} {@code payload.data}), not wrapped in {@code request_id}/{@code data}.
     */
    public boolean sendDeviceOnline(DeviceRemoteSnapshot snapshot) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("stat", buildSnapshotDataMap(snapshot));
        String id = DeviceWebSocketEnvelope.newUniqueMessageId();
        long ts = System.currentTimeMillis();
        String json = DeviceWebSocketEnvelope.toJson("device.online", payload, id, ts);
        int jsonLen = json != null ? json.length() : 0;
        boolean ok = sendRawJson(json);
        if (ok) {
            Log.i(TAG, "device_ws device.online sent outboundId=" + id + " jsonLen=" + jsonLen);
        } else {
            Log.w(TAG, "device_ws device.online failed outboundId=" + id + " jsonLen=" + jsonLen);
        }
        return ok;
    }

    private void enqueueDeviceOnlineAfterTransportOpen(long listenerGeneration) {
        final Context appContext = Utils.getApp();
        if (appContext == null) {
            Log.w(TAG, "device_ws skip device.online: application context unavailable");
            return;
        }
        ThreadPoolManager.getExecutor().execute(() -> {
            if (listenerGeneration != connectionGeneration) {
                Log.d(TAG, "device_ws skip device.online: stale connection generation");
                return;
            }
            if (!isOnlineReady()) {
                Log.w(TAG, "device_ws skip device.online: session not online");
                return;
            }
            try {
                DeviceRemoteSnapshot snapshot = new DeviceStatusPut().packRemoteSnapshot(appContext);
                if (listenerGeneration != connectionGeneration) {
                    Log.d(TAG, "device_ws skip device.online send: generation changed after snapshot build");
                    return;
                }
                sendDeviceOnline(snapshot);
            } catch (Exception ex) {
                Log.e(TAG, "device_ws device.online handling failed", ex);
            }
        });
    }

    private static Map<String, Object> buildSnapshotDataMap(DeviceRemoteSnapshot snapshot) {
        Map<String, Object> dataMap = snapshotToMap(snapshot);
        return dataMap != null ? dataMap : Map.of();
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> snapshotToMap(DeviceRemoteSnapshot snapshot) {
        if (snapshot == null) {
            return Map.of();
        }
        String json = GsonInitUtils.getGson().toJson(snapshot);
        try {
            Map<String, Object> parsed = GsonInitUtils.getGson().fromJson(json, LinkedHashMap.class);
            return parsed != null ? parsed : Map.of();
        } catch (Exception ex) {
            return Map.of();
        }
    }

    private void handleInboundSendProcessParam(DeviceWebSocketEnvelope.Parsed env) {
        final long startMs = System.currentTimeMillis();
        final String requestId = env.id;
        long eventTs = env.ts > 0 ? env.ts : System.currentTimeMillis();
        String framePayload = GsonUtils.toJson(env.payload);
        DeviceDataEvent event = new DeviceDataEvent()
                .setDeviceId(activeSn)
                .setCorrelationId(requestId)
                .setPayload(framePayload)
                .setTimestamp(eventTs)
                .setSourceProtocol(DeviceChannelProtocol.WS)
                .setEventType("command.send_process_param");
        String validationError = DeviceChannelValidator.validate(event);
        if (validationError != null) {
            DeviceChannelTelemetry.logDataPath(event, validationError, System.currentTimeMillis() - startMs);
            sendProcessParamAck(requestId, ServerPushAckCode.FAIL, validationError);
            return;
        }
        ThreadPoolManager.getExecutor().execute(() -> {
            long t0 = System.currentTimeMillis();
            ProcessParametersPushEnvelope mq = ServerPushProcessParamPayloadParser.parse(env.payload);
            boolean success = false;
            String failureReason = null;
            ProcessParametersData persistedData = null;
            if (mq != null && mq.getData() != null) {
                try {
                    ServerPushMessageHandler.saveProcessData(mq);
                    persistedData = mq.getData().clone();
                    success = true;
                } catch (Exception ex) {
                    success = false;
                    failureReason = ex.getMessage() == null ? "processing_failure" : ex.getMessage();
                }
            } else {
                failureReason = "malformed_payload";
            }
            String outcome = success
                    ? "success"
                    : (mq == null || mq.getData() == null ? "malformed_payload" : "processing_failure");
            DeviceChannelTelemetry.logDataPath(event, outcome, System.currentTimeMillis() - t0);
            sendProcessParamAck(
                    requestId,
                    success ? ServerPushAckCode.SUCCESS : ServerPushAckCode.FAIL,
                    success ? "success" : failureReason
            );
            if (success && persistedData != null) {
                final ProcessParametersData dialogData = persistedData;
                final boolean useMMUnit = ProcessParameterDisplayRows.resolveUseMMUnit();
                mainHandler.post(() -> AutoDialogQueue.get().enqueueRemoteProcessParamReceived(
                        dialogData, useMMUnit));
            }
        });
    }

    private void handleInboundSendProcessLib(DeviceWebSocketEnvelope.Parsed env) {
        final long startMs = System.currentTimeMillis();
        final String requestId = env.id;
        long eventTs = env.ts > 0 ? env.ts : System.currentTimeMillis();
        String framePayload = GsonUtils.toJson(env.payload);
        DeviceDataEvent event = new DeviceDataEvent()
                .setDeviceId(activeSn)
                .setCorrelationId(requestId)
                .setPayload(framePayload)
                .setTimestamp(eventTs)
                .setSourceProtocol(DeviceChannelProtocol.WS)
                .setEventType("command.send_process_lib");
        String validationError = DeviceChannelValidator.validate(event);
        if (validationError != null) {
            DeviceChannelTelemetry.logDataPath(event, validationError, System.currentTimeMillis() - startMs);
            sendProcessLibAck(requestId, ServerPushAckCode.FAIL, validationError);
            return;
        }
        ThreadPoolManager.getExecutor().execute(() -> {
            long t0 = System.currentTimeMillis();
            ProcessLibraryPushPayload push = ServerPushProcessLibPayloadParser.parse(env.payload);
            boolean success = false;
            String failureReason = null;
            if (push != null && push.getLibrary() != null) {
                try {
                    ServerPushMessageHandler.saveProcessLibrary(push.getLibrary());
                    success = true;
                } catch (Exception ex) {
                    success = false;
                    failureReason = ex.getMessage() == null ? "processing_failure" : ex.getMessage();
                }
            } else {
                failureReason = "malformed_payload";
            }
            String outcome = success
                    ? "success"
                    : (push == null || push.getLibrary() == null ? "malformed_payload" : "processing_failure");
            DeviceChannelTelemetry.logDataPath(event, outcome, System.currentTimeMillis() - t0);
            sendProcessLibAck(
                    requestId,
                    success ? ServerPushAckCode.SUCCESS : ServerPushAckCode.FAIL,
                    success ? "success" : failureReason
            );
        });
    }

    private void transition(DeviceWsConnectionState next, String detail) {
        state = next;
        Log.d(TAG, "device_ws state=" + next + ", detail=" + detail + ", url=" + activeUrl);
    }

    @VisibleForTesting
    static long computeBackoffMs(long attempt) {
        if (attempt <= 1) {
            return INITIAL_BACKOFF_MS;
        }
        long exp = INITIAL_BACKOFF_MS * (1L << Math.min(attempt - 1, 10));
        return Math.min(exp, MAX_BACKOFF_MS);
    }

    @VisibleForTesting
    static String classifyCloseCode(int code) {
        if (code == 401) {
            return "auth_invalid_sn";
        }
        if (code == CLOSE_CODE_REPLACED) {
            return "replaced_by_new_connection";
        }
        return "disconnect_generic";
    }

    @VisibleForTesting
    void setAuthErrorStateForTest() {
        synchronized (this) {
            lastErrorCode = "auth_invalid_sn";
            state = DeviceWsConnectionState.OFFLINE_AUTH_ERROR;
        }
    }

    @VisibleForTesting
    boolean isAuthErrorReconnectBlocked() {
        return state == DeviceWsConnectionState.OFFLINE_AUTH_ERROR
                && "auth_invalid_sn".equals(lastErrorCode);
    }

    private final class DeviceWsListener extends WebSocketListener {
        private final long listenerGeneration;

        private DeviceWsListener(long listenerGeneration) {
            this.listenerGeneration = listenerGeneration;
        }

        @Override
        public void onOpen(WebSocket webSocket, Response response) {
            synchronized (DeviceWebSocketConnectionManager.this) {
                if (listenerGeneration != connectionGeneration) {
                    return;
                }
                cancelReconnect();
                reconnectAttempt = 0;
                lastErrorCode = null;
                transition(DeviceWsConnectionState.ONLINE, "ws transport open");
                enqueueDeviceOnlineAfterTransportOpen(listenerGeneration);
            }
        }

        @Override
        public void onMessage(WebSocket webSocket, String text) {
            if (listenerGeneration != connectionGeneration) {
                return;
            }
            onInboundMessage(text);
        }

        @Override
        public void onMessage(WebSocket webSocket, ByteString bytes) {
            if (listenerGeneration != connectionGeneration) {
                return;
            }
            onInboundMessage(bytes.utf8());
        }

        @Override
        public void onClosing(WebSocket webSocket, int code, String reason) {
            // 4409 = server closed this socket as "replaced by newer session" (spec); often received on a
            // socket we already superseded locally — avoid spamming Info-level logs.
            if (listenerGeneration != connectionGeneration) {
                Log.d(TAG, "device_ws closing (stale listener), code=" + code + ", reason=" + reason);
            } else if (code == CLOSE_CODE_REPLACED) {
                Log.d(TAG, "device_ws closing, code=" + code + ", reason=" + reason + " (expected session replace)");
            } else {
                Log.i(TAG, "device_ws closing, code=" + code + ", reason=" + reason);
            }
            webSocket.close(code, reason);
        }

        @Override
        public void onClosed(WebSocket webSocket, int code, String reason) {
            synchronized (DeviceWebSocketConnectionManager.this) {
                if (listenerGeneration != connectionGeneration) {
                    // New connectOrReconnect() already bumped generation and likely cancel()'d this socket;
                    // server still sees a disconnect but the stale listener used to return silently here.
                    if (code == CLOSE_CODE_REPLACED) {
                        Log.d(TAG, "device_ws closed (stale listener, gen=" + listenerGeneration + " current="
                                + connectionGeneration + "), code=" + code + ", reason=" + reason);
                    } else {
                        Log.w(TAG, "device_ws closed (stale listener, gen=" + listenerGeneration + " current="
                                + connectionGeneration + "), code=" + code + ", reason=" + reason);
                    }
                    return;
                }
                if (code == CLOSE_CODE_REPLACED) {
                    Log.d(TAG, "device_ws closed, code=" + code + ", reason=" + reason + " (expected session replace)");
                } else {
                    Log.w(TAG, "device_ws closed, code=" + code + ", reason=" + reason);
                }
                endConnectionFromListener(listenerGeneration);
                String codeType = classifyCloseCode(code);
                if ("auth_invalid_sn".equals(codeType)) {
                    lastErrorCode = "auth_invalid_sn";
                    cancelReconnect();
                    transition(DeviceWsConnectionState.OFFLINE_AUTH_ERROR, "ws closed code 401");
                    notifyAuthRegistrationRequired();
                    return;
                }
                if ("replaced_by_new_connection".equals(codeType)) {
                    transition(DeviceWsConnectionState.RECONNECTING, "connection replaced");
                    scheduleReconnect("connection_replaced");
                    return;
                }
                scheduleReconnect("closed code=" + code + ",reason=" + reason);
            }
        }

        @Override
        public void onFailure(WebSocket webSocket, Throwable t, Response response) {
            int statusCode = response == null ? -1 : response.code();
            synchronized (DeviceWebSocketConnectionManager.this) {
                if (listenerGeneration != connectionGeneration) {
                    Log.w(TAG, "device_ws failure (stale listener, gen=" + listenerGeneration + " current="
                            + connectionGeneration + "), status=" + statusCode + ", msg="
                            + (t == null ? "null" : t.getMessage()));
                    return;
                }
                endConnectionFromListener(listenerGeneration);
                Log.e(TAG, "device_ws failure, status=" + statusCode + ", msg=" + (t == null ? "null" : t.getMessage()), t);
                if (statusCode == 401) {
                    lastErrorCode = "auth_invalid_sn";
                    cancelReconnect();
                    transition(DeviceWsConnectionState.OFFLINE_AUTH_ERROR, "handshake failed HTTP 401");
                    notifyAuthRegistrationRequired();
                    return;
                }
                lastErrorCode = "connect_failure";
                transition(DeviceWsConnectionState.RECONNECTING, "failure status=" + statusCode + ",msg=" + t.getMessage());
                scheduleReconnect("failure");
            }
        }
    }
}
