## ADDED Requirements

### Requirement: Cyber clock / glyph-frost API

`packages/cyber_ui` SHALL provide a public clock chrome API (appearance tokens + glyph frost rendering entry points) suitable for Home time display, aligned with lws-ui `FrostClockAppearance` / glyph blur intent. Product Home SHALL be able to consume this API instead of owning all frost glyph logic in App-only code.

#### Scenario: Home can render clock via Cyber API

- **WHEN** Home builds the clock using the Cyber clock API with realtime or frozen sample mode
- **THEN** time digits update and frost chrome is applied without a second parallel blur stack outside CyberUI

### Requirement: Documented glyph-clip limits

The Cyber clock API SHALL document RK3566 limitations for true glyph-clipped live blur versus rectangular frost + fill (honest capability), matching prior App HomeClock findings.

#### Scenario: README states glyph-clip status

- **WHEN** a developer reads the cyber_ui clock documentation
- **THEN** they can tell whether glyph-clipped live blur is supported or approximated
