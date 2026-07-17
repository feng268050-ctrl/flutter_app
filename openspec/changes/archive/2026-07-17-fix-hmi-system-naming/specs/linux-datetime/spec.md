## MODIFIED Requirements

### Requirement: Timezone persisted under var lib hmi

The preferred timezone SHALL be persisted under **`/var/lib/hmi/timezone`** (or equivalent documented filename in the HMI state dir).

#### Scenario: Timezone file path

- **WHEN** user sets timezone from Demo on Linux
- **THEN** preference is stored under `/var/lib/hmi/`
