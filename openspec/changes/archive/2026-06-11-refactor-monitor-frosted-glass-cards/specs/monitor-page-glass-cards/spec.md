## ADDED Requirements

### Requirement: Monitor card chrome uses FrostedGlassCard

Monitor tab surfaces that previously used `@mipmap` image backgrounds for card or panel chrome SHALL use `FrostedGlassCard` (`com.lasercyber.lws.ui.component.dialog.FrostedGlassCard`) instead. This applies to Machine Status gauge panels and status tiles, Alarm Information left panel and metric tiles, Alarm Log outer panel, and AI Vision work-mode info panel. Functional behavior (data binding, checkbox states, scroll behavior, tab navigation) MUST remain unchanged.

#### Scenario: Machine Status gauge panels render with FrostedGlassCard

- **WHEN** the user opens Monitor → Machine Status
- **THEN** both circular gauge containers are `FrostedGlassCard` instances
- **AND** they do not use `machine_static2` or other `@mipmap` card backgrounds
- **AND** gauge dimensions and `CircleProgressView` layout remain unchanged

#### Scenario: Machine Status status tiles render with FrostedGlassCard

- **WHEN** the user opens Monitor → Machine Status
- **THEN** each status tile (Laser, Blow, Safety Lock, Gun Head Switch, Red Light, Wire Feeding, Camera) is wrapped in `FrostedGlassCard`
- **AND** tiles do not use `machine_data*` or `machine_static3` image backgrounds
- **AND** checkbox checked/unchecked semantics remain unchanged

#### Scenario: Alarm Information panel and tiles render with FrostedGlassCard

- **WHEN** the user opens Monitor → Alarm Information
- **THEN** the left scrollable alarm panel uses `FrostedGlassCard` instead of `alarm_statuc_border`
- **AND** alarm metric tiles use `FrostedGlassCard` instead of `machine_data*` / `machine_static3` backgrounds
- **AND** alarm metric bindings and checkbox display logic remain unchanged

#### Scenario: Alarm Log panel renders with FrostedGlassCard

- **WHEN** the user opens Monitor → Alarm Information and the Alarm Log panel is visible
- **THEN** the outer Alarm Log container uses `FrostedGlassCard` instead of `alarm_warn_border`
- **AND** the warn log list and action buttons behave as before

#### Scenario: AI Vision info panel renders with FrostedGlassCard

- **WHEN** the user opens Monitor → AI Vision
- **THEN** the work-mode information side panel uses `FrostedGlassCard` instead of `video_process_bg`
- **AND** the panel uses `cardBackground="transparent"` with edge-tight field rows (see scope-extension requirement below)
- **AND** functional content bindings remain unchanged

### Requirement: Monitor gauge panels differentiate via borderGradientCenter

Machine Status left and right gauge `FrostedGlassCard` containers SHALL use distinct `borderGradientCenter` values to preserve intentional left/right visual pairing. The implementation MUST NOT rely on runtime bitmap mirroring of legacy gauge background images.

#### Scenario: Left and right gauges use distinct gradients

- **WHEN** Machine Status gauge cards are rendered
- **THEN** the left gauge card uses `borderGradientCenter="bottom-left-top-right"`
- **AND** the right gauge card uses `borderGradientCenter="top-left-bottom-right"`
- **AND** no Java code sets a mirrored bitmap background on the left gauge container

### Requirement: Monitor status tiles use consistent FrostedGlass tile chrome

Machine Status and Alarm Information metric tiles that share the `290×102dp` tile size SHALL use `FrostedGlassCard` with frosted fill and `borderGradientCenter="top-left-bottom-right"` unless a specific surface documents a different gradient in the implementation design.

#### Scenario: Status tile visual consistency

- **WHEN** a `290×102dp` status or alarm metric tile is displayed on a Monitor tab
- **THEN** the tile container is a `FrostedGlassCard` with frosted fill
- **AND** the tile uses `borderGradientCenter="top-left-bottom-right"`
- **AND** label text and disabled checkbox controls remain direct functional children inside the card

### Requirement: Monitor pages use unified FrostedGlass content spacing

Monitor tab root layouts and major content blocks SHALL use `@dimen/frosted_glass_content_padding` (24dp) for outer page padding and for consistent gaps between primary panels, unless a surface documents a legacy inset in the implementation design (for example parameter-row horizontal padding inside video detail lists).

#### Scenario: Monitor tab outer padding

- **WHEN** the user opens Machine Status, Alarm Information, Work Information, or AI Vision
- **THEN** the tab content root applies `frosted_glass_content_padding` as page inset
- **AND** inter-panel column or row gaps between major blocks use the same token where applicable

### Requirement: Work Information grid items use FrostedGlassCard

Work Information ring and data stat items (`item_ring.xml`, `item_data.xml`) SHALL use `FrostedGlassCard` instead of legacy `@mipmap` image backgrounds. Grid spacing SHALL be applied via `RecyclerView` padding and `ItemDecoration` in `WorkInfoFragment`, not per-item outer margins.

#### Scenario: Work Information stat cards render with FrostedGlassCard

- **WHEN** the user opens Monitor → Work Information
- **THEN** each ring and data cell is a `FrostedGlassCard` without legacy bitmap card backgrounds
- **AND** column-aware `borderGradientCenter` MAY vary by grid position as implemented in `StatAdapter`

### Requirement: Alarm Information left panel uses grouped FrostedGlassCard sections

The Alarm Information left scroll area SHALL present Laser, Welding Gun, and Wire Feeder as separate group `FrostedGlassCard` containers. Each group MAY use `SectionHeader` and `SectionContent` for title and body layout. Two-column metric rows inside a group SHALL use `layout_weight` pairing with alternating `borderGradientCenter` on left (`top-left-bottom-right`) and right (`bottom-left-top-right`) tiles where documented in layout.

#### Scenario: Alarm Information grouped panels

- **WHEN** the user opens Monitor → Alarm Information
- **THEN** the left panel shows three named group cards (Laser, Welding Gun, Wire Feeder)
- **AND** each group uses FrostedGlass chrome consistent with Machine Status tiles
- **AND** alarm metric bindings and checkbox display logic remain unchanged

### Requirement: Alarm Log clear action uses FrostedGlassButton

The Alarm Log embedded panel clear action SHALL use `FrostedGlassButton` with `frostedGlassButtonVariant="primary"`, `drawableStart="@drawable/btn_icon_fixed_size"`, and the same icon spacing conventions as Settings action buttons.

#### Scenario: Alarm Log clear button styling

- **WHEN** the user views the Alarm Log panel on the Alarm Information tab
- **THEN** the clear action is a `FrostedGlassButton` primary control
- **AND** it does not use a legacy image-backed button background

### Requirement: AI Vision work-mode panel uses transparent FrostedGlassCard with edge-tight content

The AI Vision work-mode information side panel SHALL use `FrostedGlassCard` with `cardBackground="transparent"` and `borderGradientCenter="top-left-bottom-right"`. The panel SHALL NOT use `SectionHeader` (no title divider). Field label rows SHALL span the card content width with only inner text inset (`31dp` horizontal padding on labels and values). The card MAY extend vertically with empty space below content while the choose-video action stays at default button height at the column bottom.

#### Scenario: AI Vision info panel layout

- **WHEN** the user opens Monitor → AI Vision
- **THEN** the work-mode panel is a transparent `FrostedGlassCard` with a plain title `TextView` (no divider under the title)
- **AND** process/material/recording label backgrounds are flush with the card horizontal edges
- **AND** the choose-video control sits below the card with `frosted_glass_content_padding` gap and default `frosted_glass_action_button_height`

### Requirement: AI Vision and video surfaces use FrostedGlassCard video chrome

AI Vision and Process Video Details video player areas SHALL replace `@drawable/video_content_box` outer chrome with `FrostedGlassCard` using `cardBackground="transparent"`, `borderGradientCenter="bottom-left-top-right"` (top-right / bottom-left highlight pair), and inner content padding (`10dp`). Overlay controls inside the player (detect, replay, etc.) remain unchanged unless separately specified.

#### Scenario: AI Vision video player card

- **WHEN** the user opens Monitor → AI Vision
- **THEN** the selected-video player is wrapped in a transparent `FrostedGlassCard` with `bottom-left-top-right` border gradient
- **AND** the legacy `video_content_box` drawable is not used as the outer container background

#### Scenario: Process Video Details video player card

- **WHEN** the user opens a process video detail screen
- **THEN** the right-hand player uses the same transparent `FrostedGlassCard` video chrome as AI Vision
- **AND** the legacy `video_content_box` drawable is not used as the outer container background

### Requirement: AI Vision choose-video action uses FrostedGlassButton

The AI Vision choose-video control SHALL use `FrostedGlassButton` with `frostedGlassButtonVariant="primary"`, `borderGradientCenter="top-left-bottom-right"`, and height `@dimen/frosted_glass_action_button_height`. It SHALL NOT stretch to fill remaining column height.

#### Scenario: AI Vision choose-video button size

- **WHEN** the AI Vision tab is displayed
- **THEN** the choose-video button uses default FrostedGlass action button height
- **AND** it does not use `@drawable/process_video_details_btn` or other legacy image button backgrounds

### Requirement: Process Video Details parameter panel uses FrostedGlassCard

The Process Video Details left parameter panel (`activity_process_video_details.xml`) SHALL use `FrostedGlassCard` with `cardBackground="transparent"` and `borderGradientCenter="top-left-bottom-right"` instead of `@mipmap/video_process_bg`. List rows SHALL retain edge-tight layout (title `24dp` start inset; scroll content without extra horizontal card padding). Functional bindings and scroll behavior MUST remain unchanged.

#### Scenario: Video details parameter panel migration

- **WHEN** the user opens a process video detail screen
- **THEN** the left parameter panel is a transparent `FrostedGlassCard`
- **AND** it does not reference `video_process_bg`
- **AND** process parameter rows and values behave as before migration

### Requirement: Process Video Details delete action uses FrostedGlassButton secondary styling

The Process Video Details delete control SHALL use `FrostedGlassButton` with `frostedGlassButtonVariant="secondary"`, `drawableStart="@drawable/btn_icon_fixed_size"` (same icon resource as Alarm Log clear), and `app:drawableTint="@color/frosted_glass_button_secondary_text"` so the icon matches the destructive label color.

#### Scenario: Video details delete button

- **WHEN** the user views a process video detail screen
- **THEN** the delete action is a `FrostedGlassButton` secondary control
- **AND** the leading icon uses `btn_icon_fixed_size` tinted to the secondary text color
- **AND** it does not use `@drawable/video_delete_bg` or `@drawable/video_delete_icon`
