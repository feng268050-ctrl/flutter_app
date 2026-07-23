# segment-long-press-drag Specification

## Purpose
TBD - created by archiving change segment-long-press-drag. Update Purpose after archive.
## Requirements
### Requirement: Segment long-press drag state machine

`FrostSegmentedControl` and `FrostSegmentedControlView` with default interaction SHALL support a long-press-to-arm drag gesture on the **currently selected** segment pill, in addition to tap-to-select on unselected segments. Each control instance MUST maintain isolated gesture state with `isPillExpanded` (visual enlarge) and `isSelectionArmed` (drag may change selection).

#### Scenario: Tap unselected segment still switches immediately

- **WHEN** the user taps an unselected segment
- **THEN** that segment MUST become selected immediately
- **AND** `onSelectedIndexChange` / `OnCheckedChangeListener` MUST fire once with the new index
- **AND** click sound MUST play when `clickSoundEnabled` is true

#### Scenario: Press on selected segment does not commit on down

- **WHEN** the user presses down on the currently selected segment
- **THEN** the committed selected index MUST NOT change on pointer down
- **AND** no selection listener MUST fire until tap on another segment or successful drag release

#### Scenario: Horizontal move before enlarge does not change selection

- **WHEN** the user presses the selected segment and moves horizontally before the long-press threshold and expand animation complete
- **THEN** the committed selected index MUST remain unchanged
- **AND** `isSelectionArmed` MUST remain false

#### Scenario: Pre-long-press move beyond touchSlop cancels gesture

- **WHEN** the user presses the selected segment and moves horizontally more than `touchSlop` before the long-press threshold elapses
- **THEN** the gesture MUST cancel
- **AND** the committed selected index MUST remain unchanged
- **AND** no arm or release sound MUST play

#### Scenario: Long-press enlarges selected pill

- **WHEN** the user holds a single pointer on the selected segment hit region for at least the long-press threshold (~400 ms, shared with frost sliders)
- **THEN** `isPillExpanded` MUST become true
- **AND** the selected pill MUST animate to enlarged scale (approximately 1.25× to 1.4×, default 1.3×)
- **AND** an arm click sound MUST play when `clickSoundEnabled` is true

#### Scenario: Drag after arm moves pill preview

- **WHEN** `isSelectionArmed` is true after expand animation completes and the user moves horizontally
- **THEN** the selected pill preview MUST follow the finger continuously
- **AND** segment label colors MUST reflect the preview index during drag
- **AND** the committed selected index and external listeners MUST NOT update until pointer release

#### Scenario: Release commits nearest segment

- **WHEN** the user releases after an armed drag session
- **THEN** the control MUST commit the segment index nearest to the pill preview position at release
- **AND** `onSelectedIndexChange` / `OnCheckedChangeListener` MUST fire if the committed index changed
- **AND** a release click sound MUST play when `clickSoundEnabled` is true
- **AND** `isPillExpanded` and `isSelectionArmed` MUST reset to false

#### Scenario: Short press on selected segment is a no-op

- **WHEN** the user presses and releases the selected segment before the long-press threshold without exceeding touchSlop cancel
- **THEN** the committed selected index MUST remain unchanged
- **AND** no selection listener MUST fire
- **AND** no click sound MUST play

#### Scenario: Multiple segment controls are independent

- **WHEN** two or more `FrostSegmentedControlView` instances are visible and the user long-press drags one control only
- **THEN** only that control MUST enter armed drag state
- **AND** other controls MUST remain unchanged

