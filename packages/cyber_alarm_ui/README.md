# cyber_alarm_ui

Shared Flutter warn/alarm frost chrome for LWS product HMIs: card-only cream
frost shell, severity-styled dialog body (WARN vs INFO), unified metrics, and
bundled warn/info icons.

**Not** an episode engine — catalog, coordinator, and ports stay in
`cyber_alarm`. **Not** HAL / Modbus / SQLite / product l10n — Apps inject
title/body/confirm copy and implement `WarnPresentation` (e.g. via a global
prompt queue).

## Typical stack

```
cyber_alarm          → episode policy + ports
cyber_alarm_ui       → frost shell / dialog body / icons
product App          → adapters, l10n, SFX, GlobalPromptQueue host
```
