## ADDED Requirements

### Requirement: Home bottom quick actions placement

The home screen SHALL show **Monitor** and **Settings** as **adjacent** 1×1 quick actions on the **start** side of the bottom shortcut row, with **Monitor** immediately to the **left** of **Settings**.

#### Scenario: Read order left-to-right on the dashboard

- **WHEN** the user views the home dashboard bottom shortcuts
- **THEN** the **Monitor** tile appears to the left of the **Settings** tile in the **same horizontal group**.

### Requirement: AI Vision wide entry tile

The home screen SHALL expose an **AI Vision** quick action in the shortcut area previously used for the standalone **Settings** corner placement. The AI Vision control SHALL occupy **approximately twice** the horizontal space of one **Monitor** or **Settings** 1×1 glazed tile while using the **same visual language** (translucent rounded container, glowing accent icon treatment, white caption consistent with sibling shortcuts).

#### Scenario: Wide tile distinguishes AI Vision entry

- **WHEN** the user views the home dashboard bottom shortcuts
- **THEN** the **AI Vision** quick action presents a horizontal layout **wider** than each 1×1 neighbor and carries the label **AI Vision** localized per app language rules.

### Requirement: Navigate to AI Vision from home

When the user activates the **AI Vision** home shortcut, the app SHALL navigate directly to the **AI Vision** experience (the AI Vision surface within device monitoring).

#### Scenario: Open AI Vision without manual tab switching

- **WHEN** the user taps **AI Vision** on the home screen
- **THEN** the application opens **DeviceMonitoringActivity** or its successor aggregate screen **with AI Vision visible** immediately (same content as selecting the AI Vision top tab).

### Requirement: Preserve existing shortcuts

Selecting **Monitor** SHALL continue to open the device monitoring screen with **default tab** behavior unchanged from before this change. Selecting **Settings** SHALL continue to open the device settings screen.

#### Scenario: Monitor unchanged

- **WHEN** the user taps **Monitor**
- **THEN** the application opens monitoring with the existing default landing tab unchanged.

#### Scenario: Settings unchanged

- **WHEN** the user taps **Settings**
- **THEN** the application opens **DeviceSettingActivity** as before.
