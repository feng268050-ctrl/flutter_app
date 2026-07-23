## Why

The product targets English-speaking users, but the Monitor and Settings top tab bar uses layouts that clip or squeeze long English tab titles. On the Monitor **Alarm Information** screen, the left status panel uses a three-column grid with relatively narrow metric tiles (224dp), which causes awkward line breaks for English labels. The **Welding Gun** group currently places three metrics in one row, which exacerbates the problem for labels like “Gun Comm Status” and the temperature fields.

## What Changes

- Increase effective width and/or minimum sizing for top tab items so English tab titles on **Monitor** and **Settings** read fully without truncation where feasible (shared `TopTabView` / tab item layout / `TabLayout` attributes).
- On **Alarm Information** (`fragment_warn_info.xml`), constrain the left panel’s metric grids to **two columns** per row so each tile is wider and labels wrap less often; adjust row/column indices and spans as needed so the visual order stays coherent.
- In the **Welding Gun** section: **Gun Comm Status** alone on the **first** row (e.g. span two columns); the **two temperature** indicators on the **second** row (one column each).

## Capabilities

### New Capabilities

- `monitor-settings-top-tab-navigation`: Readable English tab labels on Monitor and Settings via wider tab chrome (shared top tab component and layouts).
- `alarm-information-left-panel-layout`: Left-panel alarm metric grids use at most two columns per row; Welding Gun group uses a two-row layout (comm status first row, temperatures second row).

### Modified Capabilities

- (none) — no existing OpenSpec capability in `openspec/specs/` governs this UI; requirements are introduced by the new specs above.

## Impact

- Android UI: `TopTabView`, `view_top_tab.xml`, `tab_item_layout.xml` (and any related dimensions or `TabLayout` styling).
- Alarm UI: `fragment_warn_info.xml` (`GridLayout` column counts, cell widths, `layout_columnSpan` / row-column positions for Laser Device, Welding Gun, and any other left-panel grids per design).
- String resources unchanged unless a separate copy fix is needed (e.g. duplicate label strings are out of scope unless explicitly requested).
