## Context

The app already supports multi-language resources, but some weld-mode UI strings still appear in English after switching to Simplified Chinese. This usually happens when `values-zh` entries are missing/inconsistent, or when display text is sourced from persisted/default strings without locale normalization.

The target area is engineer weld flows (Continuous Weld and Spot Weld), including static labels, selector entries, and name-edit default prefill text.

## Goals / Non-Goals

**Goals:**
- Ensure `zh-CN` locale shows Chinese copy consistently in weld-mode parameter screens and related dialogs.
- Ensure locale switching updates visible labels/defaults without altering data semantics.
- Keep custom user-entered names unchanged.

**Non-Goals:**
- No redesign of weld UI layout/interaction.
- No DB migration or rewriting historical records.
- No changes to protocol fields or process-material encoding logic.

## Decisions

1. **Fix resource truth first**
   - Audit and correct `values-zh` entries for weld-mode strings that are still English.
   - Rationale: resource-level correctness is the least risky and easiest to maintain.

2. **Retain display-time normalization for known built-in names**
   - Keep using locale-aware mapping for known built-in material-derived names used in selected/current/default-prefill display.
   - Rationale: covers persisted legacy names while avoiding storage mutation.

3. **Protect custom text**
   - Exclude user-defined/custom names from forced translation.
   - Rationale: preserves operator intent and prevents accidental content change.

## Risks / Trade-offs

- **[Risk] Hidden English copy paths may be missed** → **Mitigation:** include targeted UI verification checklist across static labels, popup options, and edit prefill.
- **[Risk] Over-normalization alters custom names** → **Mitigation:** keep strict known-label matching and custom-type bypass.
- **[Trade-off] Stored source string may differ from displayed locale copy** → **Mitigation:** acceptable as display-only localization; IDs/semantics remain source of truth.

## Migration Plan

1. Update Chinese resources for identified weld-mode labels still in English.
2. Ensure jump/edit prefill and material display paths use locale-normalized display values.
3. Verify in-device:
   - Switch to Chinese: no English leftovers in targeted flows.
   - Switch to English: existing English behavior remains correct.
4. Rollback by reverting resource/runtime-localization changes if regressions appear.

## Open Questions

- Should we expand the same Chinese-copy audit to non-weld engineer pages in this change, or keep the scope limited to reported weld-mode paths?
