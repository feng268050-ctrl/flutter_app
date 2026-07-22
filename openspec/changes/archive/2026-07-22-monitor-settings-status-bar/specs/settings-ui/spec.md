## ADDED Requirements

### Requirement: Settings shell and sub-pages use the CyberUI page status bar

The Settings shell and Settings sub-pages hosted by the shared Settings scaffold SHALL use the CyberUI **page status bar** (leading back, centered title, trailing extensible `CyberHomeStatusBar` + compact clock). For this product’s current icon set the trailing bar SHALL include Wi‑Fi · Bluetooth · camera. Sub-pages MUST inherit this chrome from the shared scaffold so operators see consistent top chrome without per-page one-off AppBars or App-local status-bar forks. Existing Settings body content, tabs, and CyberUI/Material content chrome requirements remain unchanged.

#### Scenario: Settings shell top chrome includes status and clock

- **WHEN** the operator opens Settings
- **THEN** the Settings top chrome is the CyberUI page status bar showing back, the Settings title, this product’s current status icons, and a compact clock

#### Scenario: Settings sub-page scaffold includes status and clock

- **WHEN** the operator opens Common Settings → Wi‑Fi (or another Settings scaffold sub-page)
- **THEN** the sub-page top chrome is the CyberUI page status bar showing back, that page’s title, this product’s current status icons, and a compact clock
