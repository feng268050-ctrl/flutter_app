## ADDED Requirements

### Requirement: Forget-network actions match Safety Operation Tips primary button styling

The system SHALL present the `Forget This Network` action on the WiFi details page and the **Confirm** and **Cancel** actions on the forget-network confirmation dialog using the same primary button visual treatment as the **AGREE** button on the Safety Operation Tips screen (including background drawable, text size, and default enabled text color as defined for that AGREE control in layout resources).

#### Scenario: Forget action matches AGREE styling

- **WHEN** the WiFi details page is displayed
- **THEN** the `Forget This Network` control uses the same primary button styling pattern as the Safety Operation Tips AGREE button

#### Scenario: Confirmation dialog actions match AGREE styling

- **WHEN** the forget-network confirmation dialog is displayed
- **THEN** both the confirm and cancel actions use the same primary button styling pattern as the Safety Operation Tips AGREE button
