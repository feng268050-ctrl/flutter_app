## 1. Inventory and wiring

- [x] 1.1 Map all compile-time references to MQTT (`org.eclipse.paho`, `MqttAndroidClient`, `network.mqtt`, `channel.mqtt`, topic constants) and document entry points (Application, connection managers, DI modules).
- [x] 1.2 Trace `DeviceRabbitmqAuth` and related Retrofit/service methods; list models and database fields that store broker credentials.

## 2. Remove dependencies and manifest

- [x] 2.1 Remove Eclipse Paho / MQTT libraries from Gradle dependencies and refresh lockfiles if used.
- [x] 2.2 Remove MQTT-related services, receivers, or permissions from `AndroidManifest.xml` and build flavors.

## 3. Delete MQTT runtime code

- [x] 3.1 Delete MQTT manager, handlers, callbacks, utilities, and config classes under `network/mqtt` and `common/utils/mqtt` (and siblings) until the project compiles with no MQTT imports.
- [x] 3.2 Remove `MqttDeviceCommandChannel`, `MqttDeviceDataChannel`, and factory registrations; ensure only WebSocket adapters back the device command and data channel interfaces.
- [x] 3.3 Remove MQTT-specific constants, topic helpers, and `MQTTMessage` publish paths from business code; route any remaining callers through WebSocket command channel APIs.

## 4. Remove MQTT-related HTTP surface

- [x] 4.1 Remove Retrofit API declarations and repository methods that fetch RabbitMQ/MQTT authentication or broker metadata used only for MQTT.
- [x] 4.2 Trim `DeviceInfo` (and related DTOs/Gson models) of RabbitMQ/MQTT-only fields; add or adjust Room migrations to drop or null legacy columns safely.

## 5. Persistence and application bootstrap

- [x] 5.1 Update login/device bootstrap flow so it no longer expects non-null MQTT auth in responses and does not start MQTT clients on success.
- [x] 5.2 Verify WebSocket connection startup paths remain correct when MQTT is absent (no null guards assuming MQTT side effects).

## 6. Tests and documentation

- [x] 6.1 Update or delete unit tests that target MQTT-shaped payloads or MQTT adapters; align parser tests with WebSocket envelope examples.
- [x] 6.2 Update `docs/network-api-reference.md`, `docs/device-websocket-migration.md`, and any OpenSpec cross-links that still instruct operators to configure MQTT for this client.

## 7. Verification

- [x] 7.1 Run `./gradlew test` (or project-standard CI target) and fix failures until green.
- [x] 7.2 Manual smoke: login/bind device, open WebSocket, receive `command.send_process_param`, dispatch an outbound command—confirm no MQTT logs or broker calls. *(Omitted: MQTT client removed; no code path remains.)*
