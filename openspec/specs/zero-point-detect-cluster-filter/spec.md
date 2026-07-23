# zero-point-detect-cluster-filter Specification

## Purpose
TBD - created by archiving change zero-point-java-cluster-filter. Update Purpose after archive.
## Requirements
### Requirement: Cluster valid zero-point samples within 16px tolerance

The App SHALL provide a pure-Java reducer that accepts an ordered list of native-valid zero-point samples (`ok == true`) for a single detection round. Two samples SHALL belong to the same cluster when **both** `|offset_x₁ − offset_x₂| ≤ 16` and `|offset_y₁ − offset_y₂| ≤ 16` (axis-aligned tolerance, `CLUSTER_TOLERANCE_PX = 16`).

#### Scenario: Nearby samples merge into one cluster

- **WHEN** a round contains valid samples at offsets `(0, 0)`, `(2, 1)`, and `(−1, 2)`
- **THEN** the reducer SHALL place all three in one cluster

#### Scenario: Distant samples form separate clusters

- **WHEN** a round contains valid samples at `(0, 0)` and `(20, 0)`
- **THEN** the reducer SHALL form two clusters of size 1

### Requirement: Select winning cluster by highest occurrence count

When multiple clusters exist, the reducer SHALL select the cluster with the **largest member count**. When two clusters tie on count, the reducer SHALL select the cluster whose mean `(offset_x, offset_y)` is lexicographically smallest (deterministic tie-break).

#### Scenario: Larger cluster wins

- **WHEN** cluster A has 3 members and cluster B has 1 member
- **THEN** the reducer SHALL select cluster A

#### Scenario: Tie-break on equal cluster sizes

- **WHEN** two clusters each have 2 members and cluster A mean offset is `(−5, 0)` while cluster B mean is `(3, 0)`
- **THEN** the reducer SHALL select cluster A

### Requirement: Representative sample is nearest to cluster center

From the winning cluster, the reducer SHALL compute the cluster center as the arithmetic mean of member `offset_x` and `offset_y`. The representative sample SHALL be the member whose Euclidean distance to that center is minimal. When multiple members tie on distance, the reducer SHALL choose the member with the **earliest arrival index** in the input list.

#### Scenario: Pick closest to centroid

- **WHEN** the winning cluster has members `(0, 0)`, `(4, 0)`, `(0, 4)` with center approximately `(1.33, 1.33)`
- **THEN** the representative SHALL be `(0, 0)` (closest to center)

#### Scenario: Tie-break by earliest index

- **WHEN** two members are equidistant to the cluster center
- **THEN** the reducer SHALL return the member that arrived first in the round

### Requirement: Round anchor rejects samples beyond 10px from first detection

For a single detection round, the **first** native-valid sample in arrival order SHALL be the round anchor. Any **subsequent** valid sample whose Euclidean distance from the anchor in offset space exceeds **10px** (`ROUND_ANCHOR_MAX_DEVIATION_PX`) SHALL be marked invalid for anchor filtering. The anchor sample itself SHALL never be rejected by this rule.

#### Scenario: Subsequent outlier rejected by anchor rule

- **WHEN** the first valid sample is `(0, 0)` and a later valid sample is `(12, 0)`
- **THEN** the later sample SHALL be anchor-rejected

#### Scenario: First sample always kept

- **WHEN** the first valid sample is `(20, 0)` and all later samples are within 10px of it
- **THEN** the anchor sample SHALL remain eligible

### Requirement: Cluster selection has priority over anchor filtering

When anchor filtering and full-sample clustering disagree on the winning cluster, **cluster selection on all native-valid samples SHALL take priority**. Concretely: if the largest cluster formed from all valid samples has **strictly more members** than the largest cluster formed only from anchor-filtered samples, the reducer SHALL use the all-sample clustering result.

#### Scenario: Full-sample cluster wins over anchor subset

- **WHEN** the first valid sample is an outlier at `(50, 0)`, four later samples cluster at `(0, 0)` within 16px, and anchor filtering would leave only the outlier
- **THEN** the reducer SHALL select the `(0, 0)` cluster from all valid samples

#### Scenario: Anchor filtering applies when cluster sizes do not favor full set

- **WHEN** anchor filtering removes one stray sample and the remaining set has the same winning cluster as the full set
- **THEN** the reducer MAY use the anchor-filtered result

### Requirement: One laser on-to-off cycle is one detection round

A detection round SHALL correspond to one laser **ON → OFF** cycle for the calling coordinator. Samples from different rounds SHALL NOT be clustered together.

#### Scenario: Production coordinator round boundary

- **WHEN** `ZeroPointDetectCoordinator` completes a four-sample task for `eventId=N`
- **THEN** only samples collected for `eventId=N` SHALL be passed to the reducer for that invocation

#### Scenario: Manual auto stage round boundary

- **WHEN** `ZeroPointManualAutoCoordinator` finalizes the `online_500ms` stage
- **THEN** only online samples collected during that laser-on period for the active `runId` SHALL form one reducer input list

### Requirement: Reducer output drives downstream offset aggregation

When the reducer returns a representative sample, downstream code SHALL use that sample's `offset_x` and `offset_y` as the round's aggregated offset (replacing arithmetic mean over the raw list). When the reducer returns no representative (empty input or no valid clusters), downstream code SHALL treat the round as having zero valid samples.

#### Scenario: Single representative replaces mean

- **WHEN** a round has three valid samples and the reducer selects representative `offset_x = −9`, `offset_y = 0`
- **THEN** `meanOffsetX` for correction SHALL be `−9.0` and `meanOffsetY` SHALL be `0.0`

#### Scenario: No valid output

- **WHEN** a round has zero native-valid samples
- **THEN** the reducer SHALL return empty and correction SHALL NOT be applied

