## ADDED Requirements

### Requirement: Overlay host for Cyber dialogs

CyberUI SHALL provide an overlay/dialog host (stand-in for lws-ui `FrostOverlayHost`) that presents modal chrome using Cyber panel shell + blur sample modes. Product Apps SHALL use this host (or `showCyberDialog` built on it) instead of ad-hoc full-screen Material dialogs when frosted modal chrome is required.

#### Scenario: Show and dismiss modal

- **WHEN** the App shows a Cyber dialog via the host API and the user dismisses it
- **THEN** the overlay is removed and underlying route interaction resumes

### Requirement: Backdrop freeze during overlay

While a Cyber overlay that opts into freeze policy is visible, page-level glass consumers MUST be able to freeze or stop live backdrop sampling (aligned with lws-ui freeze-during-overlay). Live blur MAY continue only on the dialog card when explicitly requested.

#### Scenario: Page cards freeze while overlay open

- **WHEN** an overlay with freeze policy is shown over a page that uses Cyber backdrop scope
- **THEN** page chrome does not continue unbounded realtime backdrop capture for sibling cards (frozen or deferred per design)
