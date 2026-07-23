## Context

English locale behavior in engineer-mode weld screens is partially localized, but jump/edit flow still opens process-name input with Chinese defaults in some paths. The issue likely comes from persisted default names (often material-derived Chinese labels) being displayed directly without locale-aware transformation before prefill.

This change should keep all process/material semantics intact while ensuring UI default text follows active locale when entering the rename/edit dialog via jump actions.

## Goals / Non-Goals

**Goals:**
- Ensure jump/edit process-name default text is English when locale is English.
- Keep existing process ID/material type/storage semantics unchanged.
- Cover Continuous Weld and Spot Weld entry paths consistently.

**Non-Goals:**
- No DB migration or mass rewrite of stored historical names.
- No redesign of rename dialog UI/interaction.
- No changes to process selection/switching business rules.

## Decisions

1. **Apply display-time localization for known material-derived names**
   - Before rendering default process name in jump/edit flow, map known material labels to locale-specific strings.
   - Rationale: minimal risk, avoids destructive storage mutations.
   - Alternative considered: rewrite DB names on locale switch. Rejected to avoid data churn and rollback complexity.

2. **Keep custom user-defined names untouched**
   - Only normalize known built-in labels; arbitrary custom names remain as entered.
   - Rationale: preserves user intent and avoids false translation.

3. **Centralize localization utility**
   - Reuse a common helper for known material-name localization so dropdown/current-name/edit-default are consistent.
   - Rationale: prevents drift across multiple UI paths.

## Risks / Trade-offs

- **[Risk] Some Chinese defaults may not match known mapping set** → **Mitigation:** include legacy aliases in mapping (e.g., 铝板/铝合金) and add follow-up if new aliases appear.
- **[Risk] Over-localizing custom names** → **Mitigation:** limit conversion strictly to known built-in material labels.
- **[Trade-off] Stored name may differ from displayed locale text** → **Mitigation:** acceptable because behavior is display-only and semantic IDs remain source of truth.

## Migration Plan

1. Add/extend locale-aware known-label display conversion for process-name defaults.
2. Wire conversion into jump/edit prefill path(s) used by Continuous Weld and Spot Weld.
3. Verify:
   - English locale: jump/edit default process name appears in English.
   - Chinese locale: original Chinese labels still appear.
   - Custom user names remain unchanged.
4. Rollback: revert display conversion wiring if any regression appears.

## Open Questions

- Should we also localize historical process names in list views beyond jump/edit defaults, or keep scope limited to reported entry points?
