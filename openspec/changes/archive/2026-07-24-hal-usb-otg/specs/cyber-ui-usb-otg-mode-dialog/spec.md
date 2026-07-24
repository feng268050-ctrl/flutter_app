## ADDED Requirements

### Requirement: Reusable OTG mode-picker dialog

CyberUI SHALL provide a reusable **OTG mode-picker** dialog (widget and/or `show*` entry point) built on the Cyber dialog host so any product App can present the same chrome (e.g. Settings or future UIs). The picker SHALL accept an injectable ordered list of mode options (stable id + operator-visible label) and a dialog title. Selecting an option SHALL complete with that mode id; dismiss without selection SHALL complete without applying a mode. The widget MUST NOT depend on `cyber_hal` or call `UsbOtg` itself—Apps wire the option list and invoke HAL after selection.

This dialog MUST NOT be required for cable-insert flows; attach-driven presentation is out of scope.

### Requirement: Standard English copy for OTG mode picker

Unless a product overrides title/labels, the shared picker SHALL use this English copy:

- **Title:** `Select USB Mode`
- **`debug`:** `Debug over USB`
- **`mtp`:** `Media Transfer Protocol`
- **`host`:** `Connect Gadget`

CyberUI MAY export a convenience preset that builds the standard option list with these labels. Products that inject custom labels MUST keep mode ids as `debug` / `mtp` / `host` when calling `UsbOtg.setMode`.

#### Scenario: Standard three labeled modes

- **WHEN** a product shows the OTG mode picker with the standard three-mode option list
- **THEN** the dialog title is `Select USB Mode`
- **AND** the choices are labeled `Debug over USB`, `Media Transfer Protocol`, and `Connect Gadget` for ids `debug`, `mtp`, and `host` respectively

#### Scenario: Two-mode list omits host

- **WHEN** a product shows the OTG mode picker with debug + mtp only
- **THEN** the dialog title is `Select USB Mode`
- **AND** the choices are labeled `Debug over USB` and `Media Transfer Protocol` only

#### Scenario: Selection returns mode id

- **WHEN** the operator selects the row labeled `Media Transfer Protocol`
- **THEN** the picker API returns / invokes with mode id `mtp`

#### Scenario: No HAL dependency in CyberUI

- **WHEN** integrators inspect the CyberUI OTG mode-picker package graph
- **THEN** it does not import `package:cyber_hal`
