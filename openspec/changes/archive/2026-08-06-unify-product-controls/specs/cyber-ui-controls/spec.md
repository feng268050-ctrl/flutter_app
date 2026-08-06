## ADDED Requirements

### Requirement: Checkbox face size tiers for product callers

CyberUI SHALL expose checkbox face sizes only as `CyberDimens.checkboxSmallSize` and `CyberDimens.checkboxLargeSize`. Product App call sites that show operator checkboxes SHALL use these tiers (large = 28 for product toggles and don’t-show-again). Product code MUST NOT invent additional face sizes for `CyberCheckbox`.

#### Scenario: Large tier is twenty-eight

- **WHEN** a product surface requests the large checkbox tier
- **THEN** the face edge length is 28 logical pixels
