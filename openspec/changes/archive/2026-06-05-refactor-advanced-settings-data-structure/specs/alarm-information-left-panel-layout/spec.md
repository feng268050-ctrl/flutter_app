## ADDED Requirements

### Requirement: Alarm Information temperature metrics respect common settings unit

On Monitor → Alarm Information (`WarnInfoFragment` / `fragment_warn_info.xml`), every temperature **value** tile SHALL format its displayed reading according to `t_common_settings.unit` (the same `commonSettings.unit` preference as Advanced Settings).

- Modbus / in-memory sensor values remain in **Celsius**; only the on-screen formatted text changes.
- When `unit` is `metric`, temperature tiles MUST show Celsius with a `℃` suffix (same decimal precision as today, e.g. one decimal for register-scaled gun/protection/collimator readings).
- When `unit` is `imperial`, temperature tiles MUST convert Celsius to Fahrenheit for display with an `°F` suffix, using the same conversion rules as `TemperatureUnitConvertUtil` on Advanced Settings.
- Invalid or disconnected sensor placeholders (e.g. `- ℃`) MUST remain non-numeric error placeholders and MUST NOT be converted.
- Alarm checkbox / fault evaluation bindings MUST continue to use raw Celsius thresholds and status bits; unit conversion applies to **display text only**.

Temperature tiles covered include at minimum: environment temperature, gun driver board temperature, gun motor temperature, protection lens temperature, and collimating lens temperature. Any other active temperature metric on the same screen MUST follow the same rule.

#### Scenario: Metric unit shows Celsius on Alarm Information

- **WHEN** `t_common_settings.unit` is `metric`
- **AND** gun motor temperature raw value parses to 25.0 °C
- **AND** the user views Monitor → Alarm Information
- **THEN** the gun motor temperature tile MUST display a Celsius reading equivalent to `25.0 ℃` (formatting consistent with the current screen)

#### Scenario: Imperial unit shows Fahrenheit on Alarm Information

- **WHEN** `t_common_settings.unit` is `imperial`
- **AND** gun motor temperature raw value parses to 25.0 °C
- **AND** the user views Monitor → Alarm Information
- **THEN** the gun motor temperature tile MUST display `77.0 °F` (25 °C → 77 °F, one decimal place)

#### Scenario: Unit change refreshes temperature display without reconnecting device

- **WHEN** the user changes Advanced Settings unit from `metric` to `imperial` while Alarm Information is visible or re-opened
- **AND** underlying `DeviceData` temperature raw values are unchanged
- **THEN** all temperature value tiles on Alarm Information MUST re-render in Fahrenheit without requiring a new Modbus read

#### Scenario: Alarm logic unchanged under imperial display

- **WHEN** `t_common_settings.unit` is `imperial`
- **AND** environment temperature raw value is 5 °C (within the existing -10..40 °C healthy band)
- **THEN** the environment temperature alarm indicator MUST remain in the healthy state
- **AND** only the displayed numeric text is shown in Fahrenheit
