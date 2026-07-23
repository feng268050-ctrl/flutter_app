## Context

- **Monitor** and **Settings** use `TopTabView`, which inflates `view_top_tab.xml` (Material `TabLayout`, mode `scrollable`) and per-tab custom views from `tab_item_layout.xml` (icon + title, `singleLine="true"`).
- **Alarm Information** is `WarnInfoFragment` with `fragment_warn_info.xml`. The left column (`740dp` wide) contains titled sections (**Laser Device**, **Welding Gun**, **Wire Feeder**) each using an inner `GridLayout` with `columnCount="3"` and metric tiles at `224dp` width, with `layout_marginLeft="10dp"` on some cells for gutter spacing.

## Goals / Non-Goals

**Goals:**

- Give English tab titles enough horizontal room so they are not clipped or overly cramped on Monitor and Settings.
- Reflow the left-panel metric grids to **two columns** so tiles are wider and labels break less awkwardly.
- In **Welding Gun**, place **Gun Comm Status** on row 0 spanning both columns; place **gun driver board temperature** and **gun motor temperature** on row 1 in two columns.

**Non-Goals:**

- Changing alarm logic, bindings, or which metrics exist.
- Fixing unrelated string mistakes (e.g. duplicate English copy between `gun_head_communication_text` and `motor_driver_temperature_text` in `strings.xml`) unless explicitly requested later.
- Redesigning the right-hand alarm log area or overall `740dp` panel width.

## Decisions

1. **Tabs: adjust shared layout and TabLayout minimums**  
   Prefer changing `tab_item_layout.xml` (horizontal padding, optional `minWidth` on the root `LinearLayout` or title `TextView`) and/or `view_top_tab.xml` (`app:tabMinWidth`, `tabPaddingStart`/`End`) so both activities benefit without duplicating Java. Keep `tabMode="scrollable"` so six Settings tabs still fit by scrolling rather than crushing width.  
   *Alternatives:* Programmatic `TabLayout` configuration only in Java (more code paths); fixed `dp` tab width per activity (duplication). Rejected in favor of shared XML.

2. **Alarm grids: `columnCount="2"` and explicit placement**  
   Set `android:columnCount="2"` on each left-panel `GridLayout`. Increase tile width from `224dp` toward half the inner content width (~`336dp`–`350dp` accounting for `14dp` padding and inter-cell `10dp` margins—exact value tuned in implementation). Assign `layout_row`, `layout_column`, and for Gun Comm `layout_columnSpan="2"` so the first row is one full-width tile.  
   *Alternatives:* `ConstraintLayout` refactor (larger diff); `FlexboxLayout` new dependency. Rejected to stay within existing `GridLayout` patterns.

3. **Laser Device / Wire Feeder sections**  
   Apply the same two-column contract for consistency. Where only one child is visible (current Laser Device active content, Wire Feeder), column count 2 still works; set explicit `layout_row`/`layout_column` as needed so future enabled tiles align predictably.

4. **Margins after reflow**  
   Use consistent inter-tile spacing: prefer `layout_marginStart` on column-1 cells only (or `layout_goneMargin*` if used) so row-0 full-span cell does not double-indent.

## Risks / Trade-offs

- **[Risk] Very long future tab strings still clip** with `singleLine="true"` → Mitigation: increase min width/padding first; only if still insufficient, consider `maxLines="2"` and slightly taller tab row (product call).
- **[Risk] Full-width Welding Gun row height** vs. two narrow rows → Mitigation: keep row height `104dp` unless UX asks for taller first row.
- **[Trade-off] Scrollable tab bar** may require horizontal scroll on Settings for six tabs → Acceptable; preferable to unreadable labels.

## Migration Plan

- Ship in a normal app release; no data migration. Rollback by reverting layout/XML commits.

## Open Questions

- Exact `dp` for tile width and tab min width should be validated on the target device resolution (e.g. 1280×800) after implementation.
