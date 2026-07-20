## ADDED Requirements

### Requirement: Home glass chrome uses CyberUI

Product Home frosted surfaces (quick-action cards, and any Cyber glass used by the home clock composition) SHALL use `packages/cyber_ui` APIs (`CyberBackdropBlur` / `CyberCard` / shared sample-mode types) rather than duplicating glass implementations under `app/hmi/lib/ui/cyber` after migration. Home MUST keep a backdrop capture scope/target so frozen/on-change modes remain available when selected.

#### Scenario: Quick actions use CyberUI sample mode

- **WHEN** the user views Home quick-action Monitor / Settings / AI Vision cards after CyberUI migration
- **THEN** those cards obtain frost via CyberUI widgets configured with an explicit `CyberBlurSampleMode` (product default realtime)

#### Scenario: Home declares CyberUI dependency

- **WHEN** the App builds Home after this change
- **THEN** Home presentation code imports glass primitives from `package:cyber_ui/...` (not a forked copy under feature-local folders)

### Requirement: Home tappable chrome may play Cyber click sound

Home quick-action activations (Monitor / Settings / AI Vision) SHALL go through CyberUI tappable chrome that honors click-sound enablement once CyberUI click registry is wired. The App SHALL register a click-sound backend at startup when product click feedback is enabled.

#### Scenario: Quick action tap can trigger click sound

- **WHEN** a click-sound provider is registered and the user activates a Home quick-action card with click sound enabled
- **THEN** CyberUI click playback is invoked as part of the activation path
