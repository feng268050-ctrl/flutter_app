## 1. Top tab bar (Monitor and Settings)

- [x] 1.1 Adjust `view_top_tab.xml` (`TabLayout`) for wider minimum tab width and/or horizontal tab padding while keeping `tabMode` scrollable so six Settings tabs remain reachable.
- [x] 1.2 Adjust `tab_item_layout.xml` (root padding and/or `minWidth` on the tab row or title `TextView`) so English titles fit on one line with the icon at the default text size.
- [x] 1.3 Confirm `TopTabView` needs no Java changes; if `TabLayout` APIs are required for per-tab min width, add the smallest programmatic override in `TopTabView` only if XML is insufficient.

## 2. Alarm Information left panel (`fragment_warn_info.xml`)

- [x] 2.1 Update the **Laser Device** `GridLayout` to `columnCount="2"`, widen metric tiles from `224dp` toward the design target (~336–350dp inner tile width), and set explicit `layout_row` / `layout_column` so the visible pump/laser communication tile aligns cleanly; normalize horizontal margins between columns.
- [x] 2.2 Update the **Welding Gun** `GridLayout` to two columns: Gun Comm tile on row 0 with `layout_columnSpan="2"`; gun driver board temperature on row 1 column 0; gun motor temperature on row 1 column 1; remove obsolete `layout_marginLeft` on row-0 full-span where it breaks alignment.
- [x] 2.3 Update the **Wire Feeder** `GridLayout` to `columnCount="2"` and matching tile width/margins for consistency with the other sections.

## 3. Verification

- [x] 3.1 Build the app and visually verify Monitor and Settings top tabs (English strings) and Alarm Information left panel (Laser Device, Welding Gun two-row layout, Wire Feeder) on the target device or emulator resolution.
