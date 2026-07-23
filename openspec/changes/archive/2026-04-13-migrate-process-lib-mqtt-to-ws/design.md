## Context

- Historically MQTT `PROCESS_LIB` (2) carried the library aggregate; `MQTTMessageHandler.convertMsg` yielded `ProcessVersionMq`, `MqttDeviceDataChannel.ingest` called `ServerPushMessageHandler.saveProcessLib` / **`saveProcessLibrary`**, which replaces default/quick-mode process rows, batch-inserts from **`dataList`**, and updates `DeviceInfo.processLibVersion` from `versionCode`. MQTT ingest for `PROCESS_LIB` is removed; WebSocket replaces it. The Java aggregate is **`ProcessLibrary`** (renamed from `ProcessVersion`; see §Java 类型重命名).
- WebSocket already handles `command.send_process_param` in `DeviceWebSocketConnectionManager`: validate `DeviceDataEvent`, parse payload off the WS thread, call shared persistence, emit `DeviceChannelTelemetry`, and send `command.send_process_param_ack` with a new top-level `id` and `payload.request_id` / `code` / `message`.
- The user wants the same **command + ack** pattern for the process library, **neutral naming** for WS-facing structures (no `Mq` / MQTT identifiers on types used for parsing and handler APIs), and MQTT ingest for `PROCESS_LIB` retired once WS is live.

## Goals / Non-Goals

**Goals:**

- Dispatch inbound `command.send_process_lib` on the device WebSocket, parse `payload` into a **neutral** delivery object that carries a **`ProcessLibrary`** instance plus any correlation metadata needed for logging only (after the Java rename below, no separate `ProcessVersion` type for this aggregate).
- Call a **single** persistence entry in `ServerPushMessageHandler` (`saveProcessLibrary`) without requiring `ProcessVersionMq` / `ProcessLibraryMq` on the WS path.
- Send `command.send_process_lib_ack` after work completes (success or handled failure), using the same ack shape conventions as `command.send_process_param_ack` (new outbound `id`, `request_id` = inbound envelope `id`, numeric `code`, string `message`).
- Mirror MQTT-era observability: build `DeviceDataEvent` with `eventType` `command.send_process_lib`, `sourceProtocol` WebSocket, correlation from inbound `id`, and `DeviceChannelTelemetry` outcomes/latency comparable to `MqttDeviceDataChannel` for process-library updates.
- Deprecate MQTT `PROCESS_LIB` handling (ignore with log, or remove branch) and document **BREAKING** server expectations.

**Non-Goals:**

- Changing local Excel/XLSX import flows, OTA bundled library import, or UI-driven process library edits.
- Renaming every legacy `bean.mq.*` type project-wide in one change **except** `ProcessVersionMq` → `ProcessLibraryMq` when required by the **Java aggregate type rename** in this change’s spec.
- Broader command-router abstraction beyond what is needed to mirror the existing `send_process_param` structure.

## Decisions

1. **Neutral payload model and domain name**  
   **Decision**: Use **ProcessLibrary** as the normative name for the process-library aggregate in specs **and** as the **Java** entity class name (rename from `ProcessVersion`; see **§Java 类型重命名**). Add a small immutable-friendly POJO (e.g. `RemoteProcessLibraryCommand` or `ProcessLibraryPushPayload`) holding that aggregate plus optional `clientMessageId` / `issuedAt` if the server still sends analogs of `msgId` / `timestamp` — **without** subclassing `MQTTMessage` or using class names containing `Mq` on the WS-only parser output.  
   **Rationale**: “工艺库” aligns with `ProcessLibrary` better than `ProcessVersion`; codebase grep shows only a handful of Java references, so rename cost is low.

2. **Parser placement**  
   **Decision**: Add `ServerPushProcessLibPayloadParser` (or similarly named) alongside `ServerPushProcessParamPayloadParser`, accepting `Map<String, Object>` / envelope `payload` and returning the neutral delivery object or `null` on malformed input. Support the same JSON flexibility as agreed for process param (e.g. optional legacy `msgType` stripped or ignored, body under `data` or at root per contract).  
   **Rationale**: Keeps WS manager thin and testable.

3. **Handler API**  
   **Decision**: Library persistence entry is **`saveProcessLibrary(ProcessLibrary)`**, with body unchanged from legacy DAO logic.  
   **Rationale**: One persistence implementation; WS path uses `ProcessLibrary` only; API matches spec domain name.

4. **Where dispatch lives**  
   **Decision**: Extend `DeviceWebSocketConnectionManager.onInboundMessage` with a branch for `command.send_process_lib`, mirroring `handleInboundSendProcessParam` (synchronous validation + ack on validation failure; `ThreadPoolManager` for DB work; ack on completion). Add `sendProcessLibAck(...)` parallel to `sendProcessParamAck`.  
   **Rationale**: Matches established pattern and threading.

5. **Ack codes**  
   **Decision**: Reuse the same numeric success/failure constants as `command.send_process_param_ack` (e.g. `MQTTResponseConstants.SUCCESS` / `FAIL` if still the project standard) for consistency until a global rename of those constants is undertaken.  
   **Rationale**: Operators and backend see uniform semantics across commands.

6. **MQTT deprecation**  
   **Decision**: `PROCESS_LIB` is no longer parsed or persisted on MQTT (`MQTTMessageHandler`, `MqttDeviceDataChannel`, `MQDataAdapterFactory`); server delivery must move to WebSocket.  
   **Rationale**: Single authoritative transport for server pushes.

## Risks / Trade-offs

- **[Risk] Payload shape drift** between MQTT-era JSON and WS `payload` → parse failures or partial library writes. **Mitigation**: Document canonical JSON in `docs/network-api-reference.md`; unit tests with representative payloads; strict logs on parse failure; coordinate with backend.
- **[Risk] Rolling upgrade** (server still MQTT-only briefly). **Mitigation**: Time backend cutover after app release or short dual-delivery window if product demands — default spec assumes **BREAKING** MQTT removal for this message type.
- **[Risk] Long-running DB batch** on WS callback thread. **Mitigation**: Always run `saveProcessLibrary` work on `ThreadPoolManager` like process param.

## Java 类型重命名（`ProcessVersion` → `ProcessLibrary`）

**范围（当前仓库）**：实体 `ProcessVersion.java`、遗留包装 `ProcessVersionMq.java`（若保留则改为 `ProcessLibraryMq` + `MQTTMessage<ProcessLibrary>`）、`ServerPushMessageHandler` 的入参/日志/Javadoc；`docs/network-api-reference.md` §5.7 标题与正文；全局 `rg ProcessVersion` 清零误用。不涉及 Room 表迁移（该类型非 `@Entity`）；JSON 根字段名不变则**无需**改服务端协议。

**顺序建议**：（1）重命名实体并修编译；（2）实现 WS `command.send_process_lib` / parser / `saveProcessLibrary`；（3）若仍保留 MQTT 包装类则同步改名或删除无用类。

## Migration Plan

1. Rename Java aggregate **`ProcessVersion` → `ProcessLibrary`** and align handler + docs (may ship in the same PR as WS command or immediately before).
2. Ship app with WS command + ack + shared persistence; backend starts sending `command.send_process_lib`.
3. Verify staging: library version, row counts, `DeviceInfo.processLibVersion`, telemetry.
4. MQTT `PROCESS_LIB` ingest already removed; release notes **BREAKING** for MQTT library push.
5. Rollback: revert app release and pause WS command until server reverts.

## Open Questions

- Exact `payload` nesting (`data` only vs full legacy mirror) — **default**: match whatever `docs/network-api-reference.md` agrees with backend after implementation kickoff; parser should tolerate minimal deviation if product requires.
