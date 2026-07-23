## Why

Device operators need a prominent, style-consistent entry to the AI Vision experience from the home dashboard. Today Settings occupies a bottom quick-action slot; reordering quick actions and dedicating a wider tile to AI Vision clarifies primary navigation and matches the product direction for vision features.

## What Changes

- Move the **Settings** quick-action icon to the **left** group beside **Monitor**, in order **Monitor** (left) then **Settings** (right), matching the reference layout.
- Replace the **previous Settings position** (bottom-right 1×1 cell) with a new **AI Vision** quick action that is **horizontally wide** (occupies **twice the width** of a single 1×1 tile, i.e. 1×2 in the grid).
- **AI Vision** tile uses iconography aligned with the provided viewfinder-style eye asset and **matches existing** dark glass, rounded container, and glow accent patterns used by Monitor and Settings.
- Tapping **AI Vision** navigates **directly** to the **AI Vision** screen (same destination as the in-app AI Vision experience; no intermediate hub unless already required by app architecture).
- **Strings**: label **AI Vision** in app copy; support **English** and **Chinese** where other home quick actions are localized.

## Capabilities

### New Capabilities

- `home-dashboard-ai-vision-entry`: Layout, styling, and navigation for home dashboard bottom quick actions including Settings position, wide AI Vision tile, and tap-to-open AI Vision.

### Modified Capabilities

- _(none)_ — no existing OpenSpec capability in `openspec/specs/` currently governs home dashboard quick actions; this introduces the requirement set.

## Impact

- **UI**: Home / main dashboard layout XML (or equivalent) for bottom quick-action row; vector drawable or image asset for AI Vision icon; dimensions/styles for a 2×1 wide tile vs 1×1 peers.
- **Navigation**: Click handler wiring from home to AI Vision activity/fragment (reuse existing AI Vision route if present from device monitoring or dedicated screen).
- **Localization**: `strings.xml` / `values-zh` (and any other locales that mirror home strings).
- **Related work**: May align with in-flight `rename-ai-modes-to-ai-vision` implementation; this change is scoped to **home entry** only.
