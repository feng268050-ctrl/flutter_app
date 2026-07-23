## Context

The app already has a Network Settings flow and existing WiFi list/connection UI, but it does not provide a focused details page for the currently connected access point. Users need a lightweight screen, aligned with current visual style, to inspect connection parameters and quickly remove a network when needed.

The change touches both UI navigation and Android WiFi/network data retrieval. It also introduces a destructive management action (`Forget This Network`) that must be explicit and deterministic: disconnect first, then remove the saved configuration.

## Goals / Non-Goals

**Goals:**
- Add a connected-WiFi details page entry from Wireless Network details.
- Show core network details: IP Address, Subnet Mask, Router, and additional concise fields useful for troubleshooting.
- Keep interaction consistent with current app style, including a top back button.
- Implement `Forget This Network` as a single flow that disconnects and removes the saved network.

**Non-Goals:**
- Full parity with Android system WiFi advanced settings.
- Editing IP assignment, proxy, DNS, or security settings from this screen.
- Introducing a broader network diagnostics module.

## Decisions

1. **Dedicated details screen within existing settings flow**
   - Decision: Use a dedicated details activity/fragment under current Network Settings navigation rather than an inline expansion card.
   - Rationale: Better matches the requirement for a back-enabled top bar, keeps the list screen simple, and allows clear placement for a destructive action.
   - Alternatives considered:
     - Inline panel on list item tap: rejected due to crowded layout and weaker affordance for destructive action.
     - Modal dialog: rejected because details may exceed dialog ergonomics and reduce readability.

2. **Simplified but practical data set**
   - Decision: Display required fields (IP Address, Subnet Mask, Router) plus selected additional fields:
     - DNS
     - Signal Strength (RSSI/level)
     - Link Speed
     - Security Type
     - Frequency/Band
     - MAC (when available)
   - Rationale: Covers common troubleshooting needs while staying lightweight.
   - Alternatives considered:
     - Show only required three fields: rejected as too limited.
     - Show all Android fields: rejected for complexity and UI clutter.

3. **Forget action semantics**
   - Decision: `Forget This Network` performs disconnect + remove saved network config in one confirmed action.
   - Rationale: Aligns with user requirement and typical user expectation for “forget”.
   - Alternatives considered:
     - Separate disconnect and forget buttons: rejected as extra cognitive load and more states.

4. **Fallback behavior for unavailable data**
   - Decision: Render unavailable values as a consistent placeholder (e.g., `Not available`) and keep the screen usable even with partial data.
   - Rationale: Android APIs and device state can omit some fields; graceful degradation is required.

## Risks / Trade-offs

- **[API/permission differences across Android versions]** -> Mitigation: use compatibility-safe retrieval paths and defensive null handling for each field.
- **[Forget action may fail partially]** -> Mitigation: sequence operations with explicit success/failure handling; show user feedback for disconnect and remove outcomes.
- **[UI inconsistency with existing settings pages]** -> Mitigation: reuse existing typography, spacing, and action-button patterns from current settings layouts.
- **[Destructive action mistakes]** -> Mitigation: require confirmation before forget and provide clear button labeling.
