## ADDED Requirements

### Requirement: Persist backlight brightness percent

Setting backlight brightness from the HMI SHALL persist the clamped percent (0–100) to `/var/lib/lws-hmi/backlight-brightness` so boot restore can re-apply it without touching `hmi.service` lifecycle for network stacks.

#### Scenario: Set writes preference

- **WHEN** the operator sets backlight brightness to a valid percent
- **THEN** `/var/lib/lws-hmi/backlight-brightness` contains that percent
