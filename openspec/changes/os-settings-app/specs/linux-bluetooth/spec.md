## ADDED Requirements

### Requirement: Local adapter alias uses Brand space Model

When the OS Settings app (or HAL helper invoked for OS Settings) applies the local Bluetooth adapter alias from product identity, the Alias / display name SHALL be `"{Brand} {Model}"` with a single ASCII space, sourced from Vendor Storage identity via `ProductInfo` / equivalent. Missing Brand or Model SHALL yield a documented safe fallback (Model-only or prior adapter default) and MUST NOT require a hardcoded welding product marketing string as the permanent alias. Persistence SHALL use the existing HAL alias / `/var/lib/bluetooth/adapter-alias` path.

#### Scenario: Brand and Model both present

- **WHEN** Brand is `Innohi` and Model is `ynh960` and alias apply runs
- **THEN** BlueZ Alias / persisted adapter alias is `Innohi ynh960`
