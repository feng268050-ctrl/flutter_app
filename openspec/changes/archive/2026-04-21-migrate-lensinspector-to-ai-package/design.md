## Context

Lens-guard integration is consolidated under `com.lasercyber.lws.ai` (`NativeBridge`, `LensGuardManager`, `AssetDeployer`). Legacy package `com.lasercyber.lws.ui.lensinspector` is deprecated and must not appear as an active integration contract in code or current guides.

The migration is cross-cutting because it touches runtime imports, implementation guidance, and release expectations for `http://git.lasercyber.com/software/lws-ui`.

## Goals / Non-Goals

**Goals:**
- Keep all lens-guard package references on `com.lasercyber.lws.ai` in app code and authoritative integration docs (no active use of deprecated `*lensinspector*` Java packages).
- Preserve runtime behavior of lens-guard lifecycle, callbacks, and alert flow after package migration.
- Define a verification path that confirms no unresolved legacy package references remain.
- Keep branch delivery requirements explicit for publishing the completed migration.

**Non-Goals:**
- Rewriting native detection logic, JNI method signatures, or callback semantics.
- Redesigning lens-guard state machine, alert policy, or UI behavior.
- Changing non-lens-guard package names outside this migration scope.

## Decisions

1. **Single canonical package contract**
   - Decision: treat `com.lasercyber.lws.ai` as the only supported package path for bridge imports and documentation examples.
   - Rationale: avoids dual-support ambiguity and prevents future merge conflicts with updated engine ZIP outputs.
   - Alternative considered: temporary dual-path compatibility notes. Rejected because it prolongs deprecation risk and increases onboarding complexity.

2. **Migration validation by repository-wide search**
   - Decision: require repository-wide scan for legacy path strings as a migration completion gate.
   - Rationale: package references are spread across code and docs; a global check is the fastest objective signal of completion.
   - Alternative considered: file-by-file manual review only. Rejected due to high omission risk.

3. **No behavioral deltas beyond package references**
   - Decision: migration must be behavior-preserving and limited to namespace updates plus documentation sync.
   - Rationale: reduces regression surface and allows focused validation on startup and callback continuity.
   - Alternative considered: bundled refactor of lens manager structures. Rejected as scope creep.

## Risks / Trade-offs

- **[Risk]** Hidden legacy references in non-obvious files (docs, comments, scripts) remain after code updates.  
  **Mitigation:** perform broad string scan and include docs in acceptance checks.

- **[Risk]** Native ZIP content package path and app imports diverge across release versions.  
  **Mitigation:** document migration prerequisite and verify imported `NativeBridge` package path in integration checklist.

- **[Trade-off]** Strictly removing deprecated package naming may reduce backward compatibility with old internal docs.  
  **Mitigation:** include explicit migration notes in updated guide documents.

## Migration Plan

1. Update all Java/Kotlin imports and package-path literals tied to lens-guard native bridge usage.
2. Update markdown artifacts that describe engine ZIP structure and package locations.
3. Run search validation so deprecated package strings do not appear in active implementation guidance (allowed only as explicit deprecation notes).
4. Execute build/smoke checks needed to confirm no unresolved imports and no startup regressions in lens-guard manager wiring.
5. Publish migration changes to a GitLab branch on `http://git.lasercyber.com/software/lws-ui` following repository push workflow.

## Open Questions

- Which exact target branch name should be used for GitLab push (e.g., feature branch naming convention)?
- Should archived or historical docs preserve legacy package names with explicit “deprecated” note, or be fully rewritten?
