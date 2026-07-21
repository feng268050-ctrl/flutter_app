## ADDED Requirements

### Requirement: IME-aware dialog card lift

When a Cyber dialog or overlay hosts a CyberIME session, the dialog host (or App adapter used with `showCyberDialog` / `CyberOverlayHost`) SHALL translate the dialog card vertically using the keyboard height reported by CyberIME so the focused input remains usable above the keyboard, with a configurable margin (default 24 logical pixels). The underlying route scaffold MUST NOT be resized by this lift.

#### Scenario: Keyboard open lifts dialog card

- **WHEN** a Cyber dialog with a focused CyberIME field shows the keyboard panel
- **THEN** the dialog card is translated upward based on keyboard height
- **AND** the host route’s layout height under the overlay is unchanged

#### Scenario: Keyboard hide resets translation

- **WHEN** the CyberIME keyboard hides while the dialog remains open
- **THEN** dialog card translation returns to the pre-keyboard position

### Requirement: Backdrop sampling while keyboard visible

While a CyberIME keyboard is visible over a Cyber dialog, the dialog card’s glass sampling MUST NOT remain stuck on a pre-lift frozen capture that misaligns with the lifted card. The host SHALL use live sampling, onChange refresh, or an equivalent re-sample when lift is applied.

#### Scenario: Lift triggers sample refresh or live mode

- **WHEN** keyboard-driven lift is applied to a frosted Cyber dialog card
- **THEN** the card’s backdrop presentation updates so frosted content tracks the lifted position (live or refreshed capture)
