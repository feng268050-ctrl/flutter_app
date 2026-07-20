## ADDED Requirements

### Requirement: Home clock consumes Cyber clock API

After the Cyber clock API lands, product Home clock chrome SHALL use that API for frost/appearance instead of duplicating glyph-frost implementation solely under App feature code. App MAY retain layout/position composition.

#### Scenario: Home clock imports cyber_ui clock

- **WHEN** Phase F/G are complete
- **THEN** Home clock rendering depends on the Cyber clock API for frost glyphs/appearance tokens
