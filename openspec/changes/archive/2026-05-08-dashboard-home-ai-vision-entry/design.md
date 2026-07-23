## Context

Home screen layout is defined in `app/src/main/res/layout/activity_main.xml`. The bottom shortcuts use `android:onClick="toPage"` on container `LinearLayout`s with numeric `android:tag` values consumed in `MainActivity.toPage(Integer)` and in `HomePage.toPage(String)` (WebView bridge). **Monitor** is `box_buttons` (tag `3`, left). **Settings** is `box_buttons_settings` (tag `4`, right-aligned to parent). AI Vision lives inside **Device Monitoring** as the fifth top tab (`AiVisionFragment`, index **4** in the `ViewPager2` adapter in `DeviceMonitoringActivity`).

## Goals / Non-Goals

**Goals:**

- Place **Monitor** and **Settings** in one horizontal group under the guideline, aligned to the **start** margin, preserving existing glass-style tile (`translucent_box_fff`), icon sizing pattern (~60dp), and caption typography (22sp white).
- Occupying the **end** horizontal space (approximately where Settings sat): a **single wide** quick action (**2× the width** of one 1×1 tile—achieved by doubling the inner content row width relative to Monitor/Settings, or using a constrained width ~216dp inner area plus consistent padding—**without** shrinking the dashboard cards above).
- New tile labeled **AI Vision** with icon matching the supplied viewfinder-eye asset (vector drawable tinted or colored to match existing blue/orange accent language).
- On tap: open **AI Vision** by launching `DeviceMonitoringActivity` **with the AI Vision tab selected** immediately (avoid requiring the user to switch tabs manually).
- Keep **debounce**, **click sound**, and **NEW_TASK** behavior consistent with existing `toPage` paths.

**Non-Goals:**

- Redesign of top mode tiles, statistic cards, or placeholder/version region.
- Changing AI Vision fragment behavior beyond landing on it from home.

## Decisions

1. **Layout structure** — Wrap the Monitor and Settings stacks in a **horizontal** `LinearLayout` (or `ConstraintLayout` chain) anchored to `start`, with a fixed gap between the two 1×1 tiles (mirror margin used elsewhere, e.g. ~16–24dp). Move the Settings block markup from `constraintRight_toRightOf="parent"` into this row so order is **[Monitor][Settings]**.
2. **AI Vision placement** — Add a new clickable container **`box_buttons_ai_vision`** constrained to **`end`** of parent (same vertical band as today’s Settings row), roughly **two column widths**. Inner layout: **horizontal**: icon region + label **beside** the icon within the glazed box (matching the horizontal 1×2 brief), caption may remain below the box or integrated per final visual parity with comps—**prefer** label below the glazed box like Monitor/Settings if that reads cleaner on the device; normative UX is defined in spec (wide tile, consistent materials).
3. **Navigation contract** — Introduce an `Intent` extra on `DeviceMonitoringActivity`, e.g. `EXTRA_INITIAL_TAB_INDEX` (`int`), read in `onCreate`/after `initTab`: call `binding.deviceMonitorContainer.setCurrentItem(index, false)` and `topTabView.setSelectedTab(index)` when extra is present and in range (**0–4**). **Home AI Vision** uses index **4**. Reuse one **new** home tag integer (e.g. **`5`**) reserved for AI Vision-only entry; **`3`** stays Monitor (tab 0), **`4`** stays Settings activity.
4. **Bridge parity** — Extend `HomePage.toPage` with the same numeric mapping so embedded home WebView callers can trigger AI Vision if ever wired.
5. **Assets** — Add `drawable`/vector `ic_ai_vision_home` (from provided artwork) sized to match stroke/corner feel of existing mipmap shortcuts; optionally use **`app:tint`** or layered glow if other home icons rely on mipmaps without tint—match visually to **Monitor**/**Settings** prominence.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Deep-link tab index drifts if tab order changes | Centralize fragment order in activity or named constants; document in tasks that AI Vision maps to tab **4**. |
| Wide tile overlaps `box_card4` / margins on small densities | Use `Barrier` or guideline + `constraintWidth_max`/`0dp` width with `@dimen` for the wide tile; verify on target panel resolution. |
| Duplicate `NEW_TASK` or task affinity stacks activities oddly | Mirror existing Monitor launch flags exactly. |

## Migration Plan

- Ship layout + drawable + Intent extra in one release. Rollback: revert `activity_main.xml` and `MainActivity`/`HomePage`/`DeviceMonitoringActivity` changes; no DB migration.

## Open Questions

- Final label layout for the wide tile: icon+text inside the glazed rect vs caption below-only—resolve during implementation against the supplied mock (figure 3) while keeping glass style.
