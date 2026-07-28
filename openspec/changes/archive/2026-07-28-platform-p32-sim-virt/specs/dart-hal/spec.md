## ADDED Requirements

### Requirement: Stub backend only via HAL_BACKEND

Dart HAL Stub backends SHALL be selected only when the environment variable `HAL_BACKEND` is set to `stub` (host unit tests and emergency). Binding selection MUST NOT treat `board_id=sim` as an implicit Stub signal.

#### Scenario: Default sim is Linux-capable selection

- **WHEN** tests or runtime call `resolveHalBackend(boardId: 'sim')` without `HAL_BACKEND`
- **THEN** the kind SHALL be `linux`

#### Scenario: Host tests force stub

- **WHEN** host tests set `HAL_BACKEND=stub`
- **THEN** Stub backends SHALL be used for in-memory HAL modules
