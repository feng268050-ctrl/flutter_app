# hmi-app-navigation Specification

## Purpose
TBD - created by archiving change home-settings-ui. Update Purpose after archive.
## Requirements
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

### Requirement: Demo is not linked from product Home chrome

Product Home MUST NOT present a primary visible navigation control that opens Demo. Demo remains reachable by named route for engineering use.

#### Scenario: Home has no Demo primary entry

- **WHEN** the user views product Home
- **THEN** there is no primary Home button/label whose sole purpose is to open the P2 Demo

### Requirement: Boot self-check does not replace Home as initial route

The App’s initial route MUST remain product Home (`/`). Boot self-check, when shown, MUST be an overlay (or equivalent modal) after Home entry — it MUST NOT become the named `initialRoute` and MUST NOT remove Home/Settings/Monitor/Demo from the route table.

#### Scenario: Cold start still opens Home

- **WHEN** the HMI process starts with boot self-check enabled
- **THEN** `initialRoute` SHALL be Home
- **AND** boot self-check, if presented, SHALL appear after Home is entered

