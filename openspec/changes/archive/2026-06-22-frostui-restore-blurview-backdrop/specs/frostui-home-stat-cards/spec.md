## ADDED Requirements

### Requirement: Home stat tiles use FrostCardView

The four home-screen statistic tiles (`box_card1` through `box_card4` in `activity_main.xml`) SHALL use `com.lasercyber.lws.frostui.card.interop.FrostCardView` instead of legacy `HomeStatGlassCard`. Backdrop blur MUST sample the sibling activity `BlurTarget` via the shared `FrostBlurViewSupport` path used by other frost cards.

#### Scenario: Stat tile blur matches legacy LOW dark preset

- **WHEN** a home stat tile is shown over the home backdrop GIF
- **THEN** blur intensity and tint MUST match the former `HomeStatGlassCard` contract (`FrostBlurIntensity.LOW`, `FrostBlurTint.DARK`, no stack panel fill over blur)
- **AND** the tile MUST NOT use a separate Java blur implementation

#### Scenario: Overlay freeze uses FrostCardView API

- **WHEN** a frosted-glass dialog overlay opens over the home screen
- **THEN** stat tiles MUST freeze backdrop via `FrostCardView.freezePageBackdropDuringOverlay()`
- **AND** `MainActivity` MUST NOT reference `HomeStatGlassCard` for backdrop lifecycle

#### Scenario: Legacy HomeStatGlassCard is removed

- **WHEN** migration is complete
- **THEN** `HomeStatGlassCard.java` and `HomeStatBlurSupport.java` MUST be deleted
- **AND** grep for production references MUST return zero matches
