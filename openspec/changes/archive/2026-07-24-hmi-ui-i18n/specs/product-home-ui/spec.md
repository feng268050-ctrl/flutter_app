## ADDED Requirements

### Requirement: Home chrome uses App localization for operator text

Product Home operator-visible text chrome that is implemented as Flutter `Text` (quick-action labels, mode labels when not baked into language-agnostic art, and other migrated Home strings) SHALL use `AppLocalizations` for the active UI locale. When a Home label is currently an English-only bitmap asset, the App SHALL either replace it with localized text or ship locale-appropriate assets so Language `zh-CN` / `zh-TW` does not leave permanent English-only mode labels on Home.

#### Scenario: Home quick actions follow locale

- **WHEN** Language is `zh-CN` and the operator views Home
- **THEN** migrated Home text labels (at least Monitor / Settings / AI Vision when rendered as text) appear in Simplified Chinese

#### Scenario: Mode labels are not English-only under Chinese locale

- **WHEN** Language is `zh-CN` and Quick / Engineer mode labels are visible on Home
- **THEN** those labels are not permanently English-only bitmaps without a Chinese alternative (text or asset)
