## Why

The app has migrated device command and data paths to WebSocket; retaining MQTT adds binary size, operational surface (broker credentials, reconnect logic), and dual-transport complexity without user-visible benefit. Removing MQTT and the HTTP surfaces used only to obtain MQTT credentials simplifies the networking stack and aligns the codebase with a single device transport.

## What Changes

- Remove the Eclipse Paho MQTT client dependency and all MQTT connection, subscription, publish, and topic-handling code (managers, callbacks, utilities, Android service wiring if present).
- Delete or narrow MQTT-specific DTOs, constants, and adapters (`MqttDeviceDataChannel`, `MqttDeviceCommandChannel`, `MQTTMessageHandler`, topic helpers, etc.) so no runtime path invokes MQTT.
- Remove HTTP APIs and response models used solely for MQTT/RabbitMQ authentication or broker metadata (e.g. device RabbitMQ auth payloads and related Retrofit/service calls); ensure login/device bootstrap no longer requests or persists those fields.
- Update protocol abstraction layers and routing so command and data channels are WebSocket-only (no MQTT adapter registration, no MQTT fallback in feature flags or routing).
- **BREAKING**: Any external contract that assumed the app would connect to MQTT or call deprecated auth endpoints is removed; backend must not depend on app-side MQTT for this client.

## Capabilities

### New Capabilities

- _(none — this change removes transport and HTTP surfaces rather than introducing a new product capability.)_

### Modified Capabilities

- `device-data-channel-abstraction`: Requirements and scenarios SHALL no longer mandate or reference an MQTT adapter or “normalize MQTT payload”; ingestion SHALL be defined for the supported transport(s) (WebSocket) without MQTT parity wording where MQTT is removed.
- `device-command-channel-abstraction`: Requirements SHALL no longer describe MQTT as default fallback or dual-transport routing; command dispatch and lifecycle SHALL be specified for the remaining channel(s) only.

## Impact

- **Code**: `app/.../network/mqtt/**`, `.../channel/mqtt/**`, MQTT utilities and callbacks, `DeviceRabbitmqAuth` and callers, Gradle dependencies (`org.eclipse.paho`), ProGuard/rules if any, tests named for MQTT-shaped payloads (update or delete as appropriate).
- **Docs**: `docs/network-api-reference.md`, `docs/device-websocket-migration.md`, and any OpenSpec or inline docs that still describe MQTT setup.
- **Data**: Migrations or persisted fields tied to RabbitMQ/MQTT credentials should be removed or deprecated safely if still written to local storage.
