## MODIFIED Requirements

### Requirement: Host make upgrade-process-library auto-selects by device model

The repository SHALL provide a host helper named `make upgrade-process-library` that connects to the selected board (same USB-SSH / device selection rules as `upgrade-control-board` / `push-app`), reads the product `model` value from Rockchip Vendor Storage on the device (same source as HAL `ProductInfo.model` / `write-identity`), and selects a matching process-library package from the repository without requiring the operator to pass a model name on the Make command line. The helper MUST NOT read `model` from `/var/lib/hal/properties.ini` or legacy `product.ini`.

#### Scenario: Model read from Vendor Storage

- **WHEN** the operator runs `make upgrade-process-library` and Vendor Storage on the selected device contains a non-empty model `L1 Pro`
- **THEN** the helper SHALL use `L1 Pro` (case-insensitive match) as the device model for library selection
- **AND** SHALL NOT require a Make `MODEL=` (or equivalent) argument for that selection

#### Scenario: Missing or blank device model fails

- **WHEN** the operator runs `make upgrade-process-library` and Vendor Storage model is absent or blank
- **THEN** the helper SHALL exit non-zero with an error that states the model could not be read
- **AND** SHALL NOT upload a process-library package
