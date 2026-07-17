## MODIFIED Requirements

### Requirement: push-app stages under var lib hmi

Deployment SHALL stage files under **`/var/lib/hmi/push-app-staging/`** (HMI platform state, not network/wpa trees).

#### Scenario: Staging directory on device

- **WHEN** `make push-app` runs
- **THEN** deployment uses `/var/lib/hmi/push-app-staging/`
