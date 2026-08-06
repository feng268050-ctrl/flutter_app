# cyber-alarm-ui Specification

## Purpose
Shared Flutter warn/alarm frost chrome package (`packages/cyber_alarm_ui`): card-only frost shell, severity-styled dialog body, unified metrics, and warn/info icons. Episode policy stays in `cyber_alarm`; Apps wire presentation hosts and copy.

## Requirements

### Requirement: Shared warn frost chrome lives in cyber_alarm_ui

The product stack SHALL place reusable warn/alarm **modal frost chrome** in `packages/cyber_alarm_ui`, including at least card-only frost shell, dialog body (icon / title / body / confirm), unified layout metrics, WARN vs INFO visual chrome, and bundled warn/info icon assets. Product Apps SHALL depend on the package for that chrome and MUST NOT keep a parallel App-local copy of those widgets after migration. `packages/cyber_alarm` MUST remain Flutter-free. `packages/cyber_ui` MUST NOT own warn episode policy or product warn metrics as a substitute for this package.

#### Scenario: Second App reuses frost chrome

- **WHEN** a second product App needs the same operator warn frost dialog look
- **THEN** it SHALL depend on `packages/cyber_alarm_ui` for shell/body/metrics/icons
- **AND** MUST NOT fork a second copy of warn frost widgets under its App tree for that chrome

#### Scenario: Engine stays headless

- **WHEN** `cyber_alarm` coordinator unit tests run on host
- **THEN** they SHALL continue without a Flutter test binding for core episode logic
- **AND** `cyber_alarm` MUST NOT import `cyber_alarm_ui`

### Requirement: Package dependency boundaries for cyber_alarm_ui

`packages/cyber_alarm_ui` SHALL depend on Flutter and `cyber_ui` for chrome. It MUST NOT depend on `cyber_hal`, product App libraries, or Modbus/SQLite/SFX implementations. Dialog title, body, and confirm label SHALL be injected by the caller (App-resolved l10n / dynamic copy). Default confirm control SHALL use CyberUI button APIs sized by package metrics (not App-only `HmiButton`).

#### Scenario: Copy is injected

- **WHEN** an App presents a warn frost dialog via package widgets
- **THEN** title and body strings are supplied by the App
- **AND** the package MUST NOT hard-code product alarm EN/ZH catalog strings

#### Scenario: No HAL inside UI package

- **WHEN** package analysis or pubspec is inspected
- **THEN** `cyber_alarm_ui` MUST NOT declare a dependency on `cyber_hal`

### Requirement: WARN and INFO chrome styles

`cyber_alarm_ui` SHALL support at least two visual styles for the dialog body: **WARN** (warn icon + red title treatment) and **INFO** (info icon + black/neutral title treatment). The App SHALL choose the style when composing the dialog (including dangerous-ops / allow-* bypass paths that use INFO).

#### Scenario: WARN style default for hard alarms

- **WHEN** the App presents a non-bypass warn episode with INFO style disabled
- **THEN** the dialog body uses WARN icon and red title chrome from the package

#### Scenario: INFO style for bypassable presentation

- **WHEN** the App requests INFO style for a presented code
- **THEN** the dialog body uses INFO icon and non-red title chrome from the package

### Requirement: Unified warn card metrics

`cyber_alarm_ui` SHALL expose unified card metrics (design width, min/max height, content inset, icon/title/body/confirm sizing) so warn frost dialogs share one layout contract across Apps. Card width SHALL cap to a documented fraction of screen width. Title text SHALL fit on one line inside the content band without ellipsis when using package title fitting helpers.

#### Scenario: Card width capped

- **WHEN** screen width is narrower than the design card width
- **THEN** resolved card width MUST NOT exceed the package max-width fraction of the screen

### Requirement: App presentation host composes package widgets

The product App SHALL continue to implement the `cyber_alarm` `WarnPresentation` port with a single process host that enqueues onto the App global prompt queue. That host SHALL compose `cyber_alarm_ui` frost shell and dialog body when presenting warn/alarm frost. Non-coordinator frost prompts that already share the same chrome (for example safety ground lock INFO) SHALL also use `cyber_alarm_ui` widgets rather than App-local duplicates.

#### Scenario: WarnPresentation uses package chrome

- **WHEN** the coordinator requests presentation for an alarm code
- **THEN** the visible frost dialog chrome comes from `cyber_alarm_ui`
- **AND** enqueue remains on the App global prompt queue

#### Scenario: Shared chrome outside coordinator

- **WHEN** the App shows the safety ground lock frost prompt
- **THEN** it SHALL use `cyber_alarm_ui` shell/body widgets
- **AND** MUST NOT import deleted App-local warn frost widget paths
