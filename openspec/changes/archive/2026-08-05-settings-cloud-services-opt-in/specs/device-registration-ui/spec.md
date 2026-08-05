## ADDED Requirements

### Requirement: Registration prompts require cloud services enabled

Device registration and unbound-device bind prompts that depend on Worker connectivity or WebSocket auth failure SHALL run only while **云服务** (cloud services) is enabled. While cloud services is disabled, the system MUST NOT enqueue registration or bind dialogs from cloud probe/WebSocket paths, and MUST NOT block Home or other product flows waiting for cloud enrollment.

#### Scenario: No registration nag when cloud off

- **WHEN** cloud services is disabled
- **THEN** the system MUST NOT present the registration or bind dialog solely due to absent cloud connectivity

#### Scenario: Registration may run after enable

- **WHEN** the operator enables cloud services and the existing needs-registration classification occurs
- **THEN** the registration dialog MAY be enqueued per `device-registration-ui` rules
