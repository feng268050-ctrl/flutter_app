## ADDED Requirements

### Requirement: Monitor Videos scroll hint is readable

The Monitor -> Videos page SHALL render its dropdown, pull-scroll, or load-more hint text at a readable text size consistent with the page's primary secondary text style. The hint text MUST NOT use a size that is visually smaller than surrounding list metadata labels.

#### Scenario: User sees scroll hint text

- **WHEN** the Monitor -> Videos list shows a dropdown, pull-scroll, or load-more hint
- **THEN** the hint text MUST be readable at the same viewing distance as the video list metadata
- **AND** the hint text MUST NOT appear smaller than the list metadata labels

### Requirement: Monitor Videos loads additional pages at list end

The Monitor -> Videos page SHALL request the next video list page when the user scrolls to the end of the loaded list and the loaded item count is less than the latest `total` value. While a next-page request is in flight, the page MUST NOT start another next-page request for the same list state.

#### Scenario: Scroll reaches end with more rows

- **WHEN** the user scrolls Monitor -> Videos to the end of the loaded list
- **AND** the number of loaded videos is less than the latest `total`
- **THEN** the page MUST request the next page using the existing video list pagination command

#### Scenario: Scroll reaches end while already loading

- **WHEN** the user scrolls Monitor -> Videos to the end while a next-page request is still in flight
- **THEN** the page MUST NOT send a duplicate next-page request

#### Scenario: Scroll reaches end after all rows loaded

- **WHEN** the user scrolls Monitor -> Videos to the end
- **AND** the number of loaded videos is greater than or equal to the latest `total`
- **THEN** the page MUST NOT request another page

### Requirement: Monitor Videos footer displays loaded count and loading state

The Monitor -> Videos list footer SHALL display `{n} of {total}` when the list is not loading more data, where `n` is the number of currently loaded videos and `total` is the latest total returned by the list response. While a next-page request is in flight, the footer SHALL display a loading message instead of the count.

#### Scenario: Footer shows loaded total

- **WHEN** Monitor -> Videos has loaded `n` video rows from a response whose latest `total` is `total`
- **AND** no next-page request is in flight
- **THEN** the list footer MUST display `{n} of {total}`

#### Scenario: Footer shows loading state

- **WHEN** Monitor -> Videos is fetching the next page
- **THEN** the list footer MUST display a loading message
- **AND** the footer MUST NOT display the stale `{n} of {total}` count until loading finishes

#### Scenario: Footer updates after appended page

- **WHEN** a next-page response succeeds with additional video rows
- **THEN** the page MUST append those rows to the existing list
- **AND** the footer MUST update `n` to the new loaded row count
- **AND** the footer MUST update `total` from the latest response

### Requirement: Monitor Videos uses process terminology and lighter row separators

The Monitor -> Videos table header SHALL label the process type column as `Process Type` and the material type column as `Material Type`. Row separators in the video list SHALL be visually lightweight and MUST NOT appear as thick divider bars between rows.

#### Scenario: Table header shows updated terminology

- **WHEN** the Monitor -> Videos table header is visible
- **THEN** the process column MUST be labeled `Process Type`
- **AND** the material column MUST be labeled `Material Type`

#### Scenario: Row separators are subtle

- **WHEN** multiple video rows are visible in Monitor -> Videos
- **THEN** the separator between adjacent rows MUST render as a thin divider
- **AND** the separator MUST NOT visually dominate the row content

### Requirement: Process video details keeps process parameter heading fixed

The process video details page SHALL show a fixed section heading `Process Parameters` above the scrollable parameter rows. The heading MUST NOT be a child of the scrollable content, so scrolling the parameter rows does not move the heading. Spacing around the heading SHALL be controlled by the surrounding layout to keep top and bottom spacing visually consistent.

#### Scenario: Details heading remains fixed while rows scroll

- **WHEN** the user scrolls the process parameter rows on the video details page
- **THEN** the `Process Parameters` heading MUST remain fixed in place
- **AND** only the parameter rows MUST scroll

#### Scenario: Details heading spacing is consistent

- **WHEN** the process video details page is displayed
- **THEN** the spacing above and below the `Process Parameters` heading MUST be controlled by the parent layout
- **AND** the heading MUST NOT rely on being the first scroll-content row with a special bottom margin

### Requirement: Process video details uses updated labels and Title Case actions

The process video details page SHALL label the process type field as `Process Type`, the material field as `Material Type`, and the delete action as `Delete` in English locales.

#### Scenario: Details labels use singular material type

- **WHEN** the process video details page is displayed in English
- **THEN** the process type field MUST be labeled `Process Type`
- **AND** the material field MUST be labeled `Material Type`
- **AND** the material field MUST NOT be labeled `Materials Type`

#### Scenario: Delete action uses Title Case

- **WHEN** the process video details page is displayed in English
- **THEN** the delete action MUST be labeled `Delete`
- **AND** the delete action MUST NOT be labeled `delete`
