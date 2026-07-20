## MODIFIED Requirements

### Requirement: App defines named routes for Home, Settings, and Demo

The HMI app SHALL register named routes (or equivalent declarative path matching) for at least:

- `/` — product Home (initial route)
- `/settings` — product Settings
- `/monitor` — product Monitor
- `/demo` — P2 device Demo (trimmed)

Navigation SHALL use Flutter Navigator APIs or a small router wrapper; CyberUI is not required.

#### Scenario: Initial route is Home

- **WHEN** the app starts without a deep link
- **THEN** the initial route resolves to product Home (`/`)

#### Scenario: Settings route opens Settings shell

- **WHEN** navigation targets `/settings`
- **THEN** the Settings shell is displayed

#### Scenario: Monitor route opens Monitor

- **WHEN** navigation targets `/monitor`
- **THEN** the product Monitor screen is displayed

#### Scenario: Demo route opens Demo

- **WHEN** navigation targets `/demo`
- **THEN** the trimmed P2 Demo screen is displayed
