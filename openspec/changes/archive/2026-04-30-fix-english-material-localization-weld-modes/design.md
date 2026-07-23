## Context

Continuous Weld and Spot Weld screens display some process/material labels in English correctly, but the material picker options and selected material text still show Chinese under English locale. Existing UI appears to mix localized strings and hardcoded/default Chinese values from arrays/layout snippets.

The fix should keep current material coding/business logic unchanged while ensuring display text fully follows active locale resources.

## Goals / Non-Goals

**Goals:**
- Ensure weld-mode material dropdown and selected material text render English when app locale is English.
- Remove hardcoded Chinese display text in English-facing resource paths used by weld-mode UI.
- Keep material type identifiers/encoding stable so process parameters remain compatible.

**Non-Goals:**
- No changes to material enum numeric mapping, process DB schema, or protocol payloads.
- No redesign of welding parameter UX/layout.
- No language auto-detection changes.

## Decisions

1. **Use locale-specific string arrays as source of display text**
   - Normalize `values-en` material arrays to English labels.
   - Rationale: minimal-impact fix aligned with Android resource system.
   - Alternative considered: runtime translation map in Java/Kotlin layer. Rejected due to duplication and maintenance risk.

2. **Eliminate hardcoded Chinese fallback text in weld-related layout snippets**
   - Replace any hardcoded Chinese sample/default text used in process parameter list items with locale-safe text.
   - Rationale: prevents English UI regressions when fallback layout path is used.

3. **Preserve model-level material semantics**
   - UI text changes only; encoded material values and conversions are unchanged.
   - Rationale: avoid introducing data compatibility regressions.

## Risks / Trade-offs

- **[Risk] Other locales may still inherit Chinese if not explicitly translated** → **Mitigation:** Ensure English resources are complete for weld material labels; log follow-up for additional locales if needed.
- **[Risk] Some UI path may bypass string-array resources** → **Mitigation:** Search and replace hardcoded material display literals in weld UI code/layouts.
- **[Trade-off] Partial localization cleanup in this change** → **Mitigation:** Scope strictly to Continuous Weld/Spot Weld per reported issue, leaving broader i18n cleanup for separate change.

## Migration Plan

1. Update English resource entries for weld material options.
2. Replace hardcoded Chinese material display text in relevant weld list/layout fallback paths.
3. Build and verify English locale behavior in Continuous Weld and Spot Weld:
   - materials dropdown options in English
   - selected/current process material label in English.
4. Rollback: revert localized resource/layout deltas if unexpected regressions appear.

## Open Questions

- Are there additional weld-related popups/adapters that currently use Chinese literals not covered by the reported screens?
