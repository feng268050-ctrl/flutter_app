## ADDED Requirements

### Requirement: CyberUI package identity
The shared Flutter UI framework SHALL be named **CyberUI** and packaged for reuse across product Apps (git submodule or equivalent under `packages/cyber_ui`). The IME companion SHALL be packaged as CyberIME (`packages/cyber_ime` or documented equivalent). Product Apps MUST depend on these packages rather than forking widget implementations.

#### Scenario: App depends on CyberUI
- **WHEN** the HMI App declares UI kit dependencies for P3.0+
- **THEN** `pubspec` SHALL reference CyberUI / CyberIME package names (not `frost_ui` / `frost_ime` as the public product name)

### Requirement: Frosted Glass as initial design language
CyberUI P3.0 SHALL implement the Frosted Glass visual language aligned with lws-ui (backdrop blur: default frozen capture; optional live-while-open on explicit dialogs/modals). Public widget/type names SHOULD use the Cyber* prefix so a future design language change does not force product App renames.

#### Scenario: Default dialog backdrop
- **WHEN** a product page shows a standard Cyber dialog without requesting live backdrop
- **THEN** the backdrop SHALL use frozen (or equivalent non-live) blur policy

### Requirement: Design system swappability
CyberUI SHALL isolate look-and-feel behind theme/renderer seams so a future design refresh can replace Frosted Glass without requiring each product App to rewrite page structure (analogous to adopting a new SwiftUI appearance while keeping view hierarchy APIs).

#### Scenario: Theme seam exists
- **WHEN** CyberUI documents its theming entry points
- **THEN** there SHALL be a single documented place to register an alternate design renderer/theme without changing CyberCard / CyberDialog call sites in product Apps
